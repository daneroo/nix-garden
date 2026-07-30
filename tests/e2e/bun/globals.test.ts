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

describe("deployed GNOME global keyboard behavior", () => {
  // Alt+Shift+Q is a GNOME custom keybinding bound to `gnome-session-quit
  // --logout`, which opens the end-session dialog (Cancel / Log Out, ~60s
  // countdown). The test proves keyd carried the chord and the dialog appeared,
  // then Escape-cancels it. It never confirms log out, and never the lock
  // chord. Escape runs in a guard so the dialog is dismissed even if the
  // observation fails — the run must never leave a session counting down.
  test("Alt+Shift+Q opens the log-out dialog and Escape cancels it", async () => {
    const started = performance.now();
    let monitor: KeydMonitor | undefined;
    let originalFailure: unknown;

    const baseline = (
      await listAccessibleWindows(capabilities.atSpiAddress)
    ).map((window) => window.ref);
    const newWindows = async (): Promise<AccessibleWindow[]> => {
      const current = await listAccessibleWindows(capabilities.atSpiAddress);
      return current.filter(
        (window) => !baseline.some((ref) => sameAccessibleRef(ref, window.ref)),
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
  });
});
