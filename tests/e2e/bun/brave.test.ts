import { afterAll, beforeAll, describe, test } from "bun:test";
import {
  type ClipboardBaseline,
  captureClipboard,
  restoreClipboard,
} from "./clipboard.ts";
import {
  accessibleSubtreeHasFocus,
  type AccessibleWindow,
  focusAccessibleWindow,
  holdFailureForInspection,
  listAccessibleWindows,
  sameAccessibleRef,
  step,
  waitFor,
} from "./desktop.ts";
import {
  injectPhysicalChord,
  injectPhysicalText,
  type KeydMonitor,
  pressChord,
  startKeydMonitor,
  stopKeydMonitor,
} from "./keyboard.ts";
import { type Capabilities, validateCapabilities } from "./setup.ts";
import {
  type BraveFixture,
  type BraveProcess,
  braveLaunchLineage,
  cleanupAction,
  createFixture,
  devToolsPort,
  documentHasFocus,
  evaluateBoolean,
  fixtureWindows,
  focusFixtureTextarea,
  launchFixture,
  removeFixtureDirectory,
  seedClipboard,
  setToolkitAccessibility,
  stopFixture,
  type ToolkitAccessibilityBaseline,
  toolkitAccessibility,
  waitForPageCount,
  waitForPageTitle,
  waitForPageUrl,
} from "./brave.ts";

let capabilities: Capabilities;

async function restoreBaseline(
  baseline: AccessibleWindow | undefined,
): Promise<void> {
  if (baseline === undefined) {
    return;
  }

  const windows = await listAccessibleWindows(capabilities.atSpiAddress);
  const current = windows.find((window) =>
    sameAccessibleRef(window.ref, baseline.ref),
  );
  if (current === undefined) {
    throw new Error(
      `baseline window disappeared: ${baseline.appId} ${JSON.stringify(baseline.title)}`,
    );
  }
  if (!current.active) {
    await focusAccessibleWindow(capabilities.atSpiAddress, current);
    await waitFor(
      `baseline focus on ${baseline.appId} ${JSON.stringify(baseline.title)}`,
      async () => listAccessibleWindows(capabilities.atSpiAddress),
      (observed) =>
        observed.some(
          (window) =>
            window.active && sameAccessibleRef(window.ref, baseline.ref),
        ),
    );
  }
}

beforeAll(async () => {
  capabilities = await validateCapabilities();
}, 20_000);

afterAll(() => {
  console.log("  • Brave desktop E2E suite complete");
});

const braveLineage = braveLaunchLineage();
if (!braveLineage.ok) {
  console.log(
    `  • SKIP Brave scenario — ${braveLineage.reason}; Brave needs a visible Ghostty-rooted invoker`,
  );
}
const braveTest = braveLineage.ok ? test : test.skip;

describe("deployed Brave keyboard behavior", () => {
  braveTest(
    "physical Brave lifecycle, navigation, and clipboard chords traverse keyd",
    async () => {
      const started = performance.now();
      let fixture: BraveFixture | undefined;
      let fixtureApplication: AccessibleWindow["app"] | undefined;
      let fixtureFocused = false;
      let fixturePort: number | undefined;
      let fixtureProcess: BraveProcess | undefined;
      let fixtureProcessStopped = false;
      let accessibilityBaseline: ToolkitAccessibilityBaseline | undefined;
      let restoreToolkitAccessibility = false;
      let baseline: AccessibleWindow | undefined;
      let clipboardBaseline: ClipboardBaseline | undefined;
      let clipboardChanged = false;
      let monitor: KeydMonitor | undefined;
      let originalFailure: unknown;
      const cleanupErrors: Error[] = [];

      try {
        const initialDesktop = await listAccessibleWindows(
          capabilities.atSpiAddress,
        );
        baseline = initialDesktop.find((window) => window.active);
        if (baseline === undefined) {
          throw new Error("AT-SPI reported no active baseline window");
        }

        clipboardBaseline = await step(
          "Capture the restorable text clipboard baseline",
          captureClipboard,
        );

        accessibilityBaseline = await step(
          "Capture the GNOME toolkit-accessibility baseline",
          toolkitAccessibility,
        );
        if (accessibilityBaseline !== "true") {
          restoreToolkitAccessibility = true;
          await step(
            "Temporarily enable GNOME toolkit accessibility",
            async () => setToolkitAccessibility("true"),
          );
        }

        fixture = await step(
          "Create the isolated Brave fixture",
          createFixture,
        );
        await step(
          "Launch Brave directly from the invoking terminal",
          async () => {
            fixtureProcess = launchFixture(fixture!);
          },
        );

        fixturePort = await devToolsPort(fixture);
        const initialPages = await waitForPageCount(fixturePort, 1);
        const initialPage = initialPages.find(
          (page) => page.url === fixture!.url,
        );
        if (initialPage === undefined) {
          throw new Error(
            "DevTools did not report the exact local fixture page",
          );
        }
        const initialFixtureWindows = await waitFor(
          "one fixture-owned Brave frame",
          async () =>
            fixtureWindows(
              await listAccessibleWindows(capabilities.atSpiAddress),
              fixture!,
              undefined,
            ),
          (windows) => windows.length === 1,
        );
        const initialWindow = initialFixtureWindows[0]!;
        fixtureApplication = initialWindow.app;

        await step(
          "Verify the terminal-launched Brave fixture owns keyboard focus",
          async () => {
            await waitFor(
              "document.hasFocus() on the identified initial Brave frame",
              async () => ({
                documentFocused: await documentHasFocus(initialPage),
                windows: fixtureWindows(
                  await listAccessibleWindows(capabilities.atSpiAddress),
                  fixture!,
                  fixtureApplication,
                ),
              }),
              (observed) =>
                observed.documentFocused && observed.windows.length === 1,
            );
            fixtureFocused = true;
          },
        );

        monitor = await startKeydMonitor(capabilities.keydBinary);
        await waitFor(
          "the initial Brave textarea to retain document focus before Alt+C",
          async () => documentHasFocus(initialPage),
          (focused) => focused,
        );
        clipboardChanged = true;
        await step(
          "Select the initial Brave textarea before Alt+C",
          async () => {
            if (!(await focusFixtureTextarea(initialPage))) {
              throw new Error(
                "the fixture textarea could not be selected before Alt+C",
              );
            }
          },
        );
        console.log(
          "    • BRAVE COPY: COPY_PROBE is selected; the page will not visibly change",
        );
        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "c"] },
          { expect: { keys: ["leftCtrl", "c"] } },
        );
        await step(
          "Confirm Brave fired a copy event for COPY_PROBE (verified in-page, no external clipboard client)",
          async () =>
            waitFor(
              "the fixture page to record a COPY_PROBE copy event",
              async () =>
                evaluateBoolean(
                  initialPage,
                  '(() => (window.__copyCount || 0) > 0 && window.__lastCopy === "COPY_PROBE")()',
                ),
              (observed) => observed,
            ),
        );

        await step(
          "Seed PASTE_PROBE into the Brave clipboard from the focused page",
          async () => seedClipboard(initialPage, "PASTE_PROBE"),
        );
        await step(
          "Reselect the Brave fixture textarea before Alt+V",
          async () => {
            if (!(await focusFixtureTextarea(initialPage))) {
              throw new Error(
                "the fixture textarea could not be selected before Alt+V",
              );
            }
          },
        );
        console.log(
          "    • BRAVE PASTE: the selected textarea should visibly change to PASTE_PROBE",
        );
        const expectedPasteTitle = `${fixture!.title}-initial-PASTE_PROBE`;
        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "v"] },
          {
            expect: { keys: ["leftCtrl", "v"] },
            watch:
              "Brave textarea should visibly change from COPY_PROBE to PASTE_PROBE",
          },
        );
        await step(
          "Confirm Brave pasted PASTE_PROBE into the textarea",
          async () =>
            waitForPageTitle(fixturePort!, initialPage.id, expectedPasteTitle),
        );

        await waitFor(
          "the initial Brave page to retain document focus before Alt+N",
          async () => documentHasFocus(initialPage),
          (focused) => focused,
        );
        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "n"] },
          { watch: "a second isolated Brave window should appear" },
        );
        const pagesAfterNewWindow = await waitForPageCount(fixturePort, 2);
        const newPage = pagesAfterNewWindow.find(
          (page) => page.id !== initialPage.id,
        );
        if (newPage === undefined) {
          throw new Error("Alt+N produced no new DevTools page identity");
        }
        const newWindowState = await waitFor(
          "Alt+N to create a second fixture-owned Brave frame",
          async () =>
            fixtureWindows(
              await listAccessibleWindows(capabilities.atSpiAddress),
              fixture!,
              fixtureApplication,
            ),
          (windows) =>
            windows.length === 2 &&
            windows.some(
              (window) => !sameAccessibleRef(window.ref, initialWindow.ref),
            ),
        );
        const newWindow = newWindowState.find(
          (window) => !sameAccessibleRef(window.ref, initialWindow.ref),
        )!;
        await waitFor(
          "keyboard focus inside the new fixture-owned Brave frame",
          async () =>
            accessibleSubtreeHasFocus(capabilities.atSpiAddress, newWindow.ref),
          (focused) => focused,
        );
        await waitFor(
          "keyboard focus to remain inside the new Brave frame before Alt+W",
          async () =>
            accessibleSubtreeHasFocus(capabilities.atSpiAddress, newWindow.ref),
          (focused) => focused,
        );
        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "w"] },
          { watch: "the second Brave window should close" },
        );
        const pagesAfterClose = await waitForPageCount(fixturePort, 1);
        if (pagesAfterClose[0]?.id !== initialPage.id) {
          throw new Error("Alt+W did not preserve the initial fixture page");
        }
        await waitFor(
          "Alt+W to close the new Brave frame and retain the initial frame",
          async () =>
            fixtureWindows(
              await listAccessibleWindows(capabilities.atSpiAddress),
              fixture!,
              fixtureApplication,
            ),
          (windows) => {
            const onlyWindow = windows[0];
            return (
              windows.length === 1 &&
              onlyWindow !== undefined &&
              sameAccessibleRef(onlyWindow.ref, initialWindow.ref) &&
              !sameAccessibleRef(onlyWindow.ref, newWindow.ref)
            );
          },
        );
        await waitFor(
          "the initial Brave page to regain document focus after Alt+W",
          async () => documentHasFocus(initialPage),
          (focused) => focused,
        );
        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "t"] },
          { watch: "a new Brave tab should appear in the remaining window" },
        );
        const pagesAfterNewTab = await waitForPageCount(fixturePort, 2);
        const newTab = pagesAfterNewTab.find(
          (page) => page.id !== initialPage.id,
        );
        if (newTab === undefined) {
          throw new Error("Alt+T produced no new DevTools page identity");
        }
        await waitFor(
          "Alt+T to retain one focused fixture-owned Brave frame",
          async () => {
            const windows = fixtureWindows(
              await listAccessibleWindows(capabilities.atSpiAddress),
              fixture!,
              fixtureApplication,
            );
            return {
              focused:
                windows.length === 1 &&
                sameAccessibleRef(windows[0]!.ref, initialWindow.ref) &&
                (await accessibleSubtreeHasFocus(
                  capabilities.atSpiAddress,
                  windows[0]!.ref,
                )),
              windows,
            };
          },
          (observed) => observed.focused,
        );
        await injectPhysicalText(
          fixture.navigationUrl,
          capabilities.ydotoolSocket,
        );
        await injectPhysicalChord(
          { keys: ["enter"] },
          capabilities.ydotoolSocket,
        );
        let selectedTab = await waitForPageUrl(
          fixturePort,
          newTab.id,
          fixture.navigationUrl,
        );
        await waitFor(
          "the navigated Brave tab to hold document focus",
          async () => documentHasFocus(selectedTab),
          (focused) => focused,
        );

        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "l"] },
          { watch: "Brave should select the address bar" },
        );
        await waitFor(
          "Alt+L to retain keyboard focus inside the fixture-owned Brave frame",
          async () =>
            accessibleSubtreeHasFocus(
              capabilities.atSpiAddress,
              initialWindow.ref,
            ),
          (focused) => focused,
        );
        await injectPhysicalText(
          fixture.addressUrl,
          capabilities.ydotoolSocket,
        );
        await injectPhysicalChord(
          { keys: ["enter"] },
          capabilities.ydotoolSocket,
        );
        selectedTab = await waitForPageUrl(
          fixturePort,
          newTab.id,
          fixture.addressUrl,
        );
        await waitFor(
          "the address-navigated Brave tab to hold document focus",
          async () => documentHasFocus(selectedTab),
          (focused) => focused,
        );

        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "leftShift", "leftBracket"] },
          {
            expect: { keys: ["leftCtrl", "leftShift", "tab"] },
            watch: "Brave should select the initial COPY_PROBE tab",
          },
        );
        await waitFor(
          "Alt+Shift+[ to select the initial Brave tab",
          async () => documentHasFocus(initialPage),
          (focused) => focused,
        );

        await pressChord(
          monitor!,
          capabilities.ydotoolSocket,
          { keys: ["leftAlt", "leftShift", "rightBracket"] },
          {
            expect: { keys: ["leftCtrl", "tab"] },
            watch: "Brave should return to the address-navigated tab",
          },
        );
        await waitFor(
          "Alt+Shift+] to select the address-navigated Brave tab",
          async () => documentHasFocus(selectedTab),
          (focused) => focused,
        );
      } catch (error) {
        originalFailure = error;
        await holdFailureForInspection(
          "the Brave fixture remains visible for inspection",
        );
      }

      if (monitor !== undefined) {
        await cleanupAction(
          "Stop bounded keyd evidence capture",
          async () => stopKeydMonitor(monitor!),
          cleanupErrors,
        );
      }
      if (fixture !== undefined && fixtureProcess !== undefined) {
        await cleanupAction(
          "Stop the terminal-launched Brave process",
          async () => {
            await stopFixture(fixture!, fixtureProcess!, fixturePort);
            fixtureProcessStopped = true;
          },
          cleanupErrors,
        );
        await cleanupAction(
          "Confirm all fixture-owned Brave frames are gone",
          async () => {
            await waitFor(
              "zero fixture-owned Brave frames",
              async () =>
                fixtureWindows(
                  await listAccessibleWindows(capabilities.atSpiAddress),
                  fixture!,
                  fixtureApplication,
                ),
              (windows) => windows.length === 0,
            );
          },
          cleanupErrors,
        );
      }
      if (fixture !== undefined) {
        await cleanupAction(
          "Stop the local Brave fixture server",
          async () => {
            await fixture!.server.stop(true);
          },
          cleanupErrors,
        );
      }
      if (clipboardChanged && clipboardBaseline !== undefined) {
        await cleanupAction(
          "Restore the captured clipboard baseline",
          async () => restoreClipboard(clipboardBaseline!),
          cleanupErrors,
        );
      }
      if (fixtureFocused) {
        await cleanupAction(
          "Restore the baseline focused window",
          async () => restoreBaseline(baseline),
          cleanupErrors,
        );
      }
      if (restoreToolkitAccessibility && accessibilityBaseline !== undefined) {
        await cleanupAction(
          "Restore the GNOME toolkit-accessibility baseline",
          async () => setToolkitAccessibility(accessibilityBaseline!),
          cleanupErrors,
        );
      }
      if (
        fixture !== undefined &&
        (fixtureProcess === undefined || fixtureProcessStopped)
      ) {
        await cleanupAction(
          "Remove the isolated Brave profile",
          async () => removeFixtureDirectory(fixture!),
          cleanupErrors,
        );
      } else if (fixture !== undefined) {
        console.error(
          `  ! retained the isolated Brave profile after incomplete process cleanup: ${fixture.directory}`,
        );
      }

      console.log(
        `  • scenario elapsed ${((performance.now() - started) / 1000).toFixed(2)}s`,
      );

      if (originalFailure !== undefined) {
        if (cleanupErrors.length > 0) {
          console.error(
            `  ! preserved the original failure; ${cleanupErrors.length} cleanup action(s) also failed`,
          );
        }
        throw originalFailure;
      }
      if (cleanupErrors.length > 0) {
        throw new AggregateError(cleanupErrors, "Brave E2E cleanup failed");
      }
    },
    40_000,
  );
});
