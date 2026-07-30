import { afterAll, beforeAll, describe, test } from "bun:test";
import {
  type AccessibleWindow,
  errorMessage,
  listAccessibleWindows,
  note,
  sameAccessibleRef,
  step,
  waitFor,
} from "./desktop.ts";
import {
  injectPhysicalChord,
  type KeydMonitor,
  pressChord,
  startKeydMonitor,
  stopKeydMonitor,
} from "./keyboard.ts";
import { type Capabilities, validateCapabilities } from "./setup.ts";

let capabilities: Capabilities;

beforeAll(async () => {
  capabilities = await validateCapabilities();
}, 20_000);

afterAll(() => {
  note("• GNOME globals E2E suite complete");
});

// The log-out dialog is destructive: a failed cancel counts down to an actual
// log out. Synthetic-Escape efficacy on this gnome-shell modal is still unproven
// (the first run's auto-cancel never cleanly executed), so treat it as risky.
// Skip by default so the guarded suite never triggers it; opt in only from a
// logout-safe context (herdr, which survives logout, or a VM).
const destructiveGlobals = Bun.env.NIX_GARDEN_E2E_DESTRUCTIVE_GLOBALS === "1";
if (!destructiveGlobals) {
  note(
    "• SKIP GNOME globals — destructive log-out dialog whose synthetic cancel is unproven. Run only from a logout-safe context with NIX_GARDEN_E2E_DESTRUCTIVE_GLOBALS=1",
  );
}
const globalTest = destructiveGlobals ? test : test.skip;

describe("deployed GNOME global keyboard behavior", () => {
  // Alt+Shift+Q is a GNOME custom keybinding bound to `gnome-session-quit
  // --logout`, which opens the end-session dialog (Cancel / Log Out, ~60s
  // countdown). The test proves keyd carried the chord and the dialog appeared,
  // then Escape-cancels it. It never confirms log out, and never the lock
  // chord. Escape runs in a guard so the dialog is dismissed even if the
  // observation fails — the run must never leave a session counting down.
  globalTest(
    "Alt+Shift+Q opens the log-out dialog and Escape cancels it",
    async () => {
      const started = performance.now();
      let monitor: KeydMonitor | undefined;
      let originalFailure: unknown;

      const baseline = (
        await listAccessibleWindows(capabilities.atSpiAddress)
      ).map((window) => window.ref);
      const newWindows = async (): Promise<AccessibleWindow[]> => {
        const current = await listAccessibleWindows(capabilities.atSpiAddress);
        return current.filter(
          (window) =>
            !baseline.some((ref) => sameAccessibleRef(ref, window.ref)),
        );
      };

      try {
        monitor = await startKeydMonitor(capabilities.keydBinary);
        note(
          "• GLOBAL: Alt+Shift+Q opens the GNOME log-out dialog; the suite will Escape-cancel it (never confirm)",
        );
        await pressChord(
          monitor,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "leftShift", "q"] },
          { watch: "the GNOME log-out dialog should appear" },
        );
        const dialog = await step(
          "Observe the GNOME log-out dialog appear",
          async () =>
            waitFor(
              "a new top-level window (the end-session dialog)",
              newWindows,
              (windows) => windows.length >= 1,
              { timeoutMs: 5_000 },
            ),
        );
        note(
          `• dialog: ${dialog.map((window) => `${window.appId} ${JSON.stringify(window.title)}`).join(", ")}`,
        );
      } catch (error) {
        originalFailure = error;
      }

      // SAFETY: always Escape-cancel so the dialog never counts down to log out,
      // even if the observation above failed.
      try {
        await step("Escape-cancel the log-out dialog", async () => {
          await injectPhysicalChord(
            { keys: ["escape"] },
            capabilities.ydotoolSocket,
          );
          await waitFor(
            "the end-session dialog to be dismissed",
            newWindows,
            (windows) => windows.length === 0,
            { timeoutMs: 5_000 },
          );
        });
      } catch (cancelError) {
        note(
          `! cancel may be incomplete, retrying Escape: ${errorMessage(cancelError).split("\n")[0]}`,
        );
        await injectPhysicalChord(
          { keys: ["escape"] },
          capabilities.ydotoolSocket,
        );
      }

      if (monitor !== undefined) {
        await stopKeydMonitor(monitor);
      }

      note(
        `• scenario elapsed ${((performance.now() - started) / 1000).toFixed(2)}s`,
      );

      if (originalFailure !== undefined) {
        throw originalFailure;
      }
      // Generous test timeout so bun never kills the test before the safety
      // Escape above runs — a shorter budget once left the dialog counting down.
    },
    20_000,
  );
});
