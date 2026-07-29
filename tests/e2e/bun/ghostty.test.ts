import { afterAll, beforeAll, describe, test } from "bun:test";
import {
  type AccessibleWindow,
  errorMessage,
  focusAccessibleWindow,
  listAccessibleWindows,
  runCommand,
  sameAccessibleRef,
  step,
  waitFor,
} from "./desktop.ts";
import {
  injectPhysicalChord,
  type KeydMonitor,
  startKeydMonitor,
  stopKeydMonitor,
  waitForKeydChordEvidence,
} from "./keyboard.ts";
import { type Capabilities, validateCapabilities } from "./setup.ts";

const fixtureAppId = "org.nixgarden.e2e.Ghostty";
let capabilities: Capabilities;

interface Fixture {
  readonly configPath: string;
  readonly directory: string;
  readonly title: string;
  readonly unit: string;
}

function fixtureWindows(
  windows: readonly AccessibleWindow[],
  fixture: Fixture,
): AccessibleWindow[] {
  return windows.filter(
    (window) => window.appId === fixtureAppId && window.title === fixture.title,
  );
}

async function createFixture(): Promise<Fixture> {
  const runtimeDirectory = Bun.env.XDG_RUNTIME_DIR;
  if (runtimeDirectory === undefined) {
    throw new Error("XDG_RUNTIME_DIR is unavailable");
  }

  const directory = (
    await runCommand([
      "mktemp",
      "--directory",
      `${runtimeDirectory}/nix-garden-e2e.XXXXXX`,
    ])
  ).stdout.trim();
  const runId = directory.slice(directory.lastIndexOf(".") + 1);
  const title = `nix-garden-e2e-${runId}`;
  const configPath = `${directory}/ghostty.conf`;
  const unit = `nix-garden-e2e-ghostty-${runId}.service`;
  const fixtureProgram = `${import.meta.dir}/fixture.ts`;

  await Bun.write(
    configPath,
    [
      `initial-command = direct:/run/current-system/sw/bin/bun ${fixtureProgram}`,
      `command = direct:/run/current-system/sw/bin/bun ${fixtureProgram}`,
      "shell-integration = none",
      "confirm-close-surface = false",
      "gtk-single-instance = false",
      `class = ${fixtureAppId}`,
      `title = ${title}`,
      "",
    ].join("\n"),
  );

  return { configPath, directory, title, unit };
}

async function launchFixture(fixture: Fixture): Promise<void> {
  await runCommand([
    "systemd-run",
    "--user",
    "--collect",
    `--unit=${fixture.unit}`,
    "--property=KillMode=mixed",
    "--property=TimeoutStopSec=3s",
    "ghostty",
    `--config-file=${fixture.configPath}`,
    "--gtk-single-instance=false",
    "--initial-window=true",
  ]);
}

async function stopFixture(fixture: Fixture): Promise<void> {
  await runCommand(["systemctl", "--user", "stop", fixture.unit], {
    check: false,
  });
}

async function removeFixtureDirectory(fixture: Fixture): Promise<void> {
  const runtimeDirectory = Bun.env.XDG_RUNTIME_DIR;
  const expectedPrefix = `${runtimeDirectory}/nix-garden-e2e.`;
  if (
    runtimeDirectory === undefined ||
    !fixture.directory.startsWith(expectedPrefix) ||
    fixture.directory.includes("/../")
  ) {
    throw new Error(
      `refusing to remove unverified fixture directory ${JSON.stringify(fixture.directory)}`,
    );
  }

  await runCommand(["rm", "--recursive", "--force", "--", fixture.directory]);
}

async function cleanupAction(
  description: string,
  action: () => Promise<void>,
  errors: Error[],
): Promise<void> {
  try {
    await step(description, action);
  } catch (error) {
    const cleanupError =
      error instanceof Error ? error : new Error(errorMessage(error));
    errors.push(cleanupError);
    console.error(`  ! cleanup may be incomplete: ${cleanupError.message}`);
  }
}

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

  if (current.active) {
    return;
  }

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

beforeAll(async () => {
  capabilities = await validateCapabilities();
}, 20_000);

afterAll(() => {
  console.log("  • desktop E2E suite complete");
});

describe("deployed Ghostty keyboard behavior", () => {
  test("physical Alt+N creates and focuses a fixture-owned window through keyd", async () => {
    const started = performance.now();
    let fixture: Fixture | undefined;
    let baseline: AccessibleWindow | undefined;
    let fixtureFocused = false;
    let fixtureLaunched = false;
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

      fixture = await step(
        "Create the isolated Ghostty fixture",
        createFixture,
      );
      const loadedBindings = (
        await runCommand(["ghostty", "+list-keybinds", "--plain"])
      ).stdout;
      if (!loadedBindings.includes("keybind = alt+n=new_window")) {
        throw new Error(
          `fixture Ghostty did not load the deployed Alt+N binding:\n${loadedBindings}`,
        );
      }

      await step("Launch the fixture-owned Ghostty process", async () => {
        await launchFixture(fixture!);
        fixtureLaunched = true;
      });

      const initialFixtureWindows = await waitFor(
        "one fixture-owned Ghostty window",
        async () =>
          fixtureWindows(
            await listAccessibleWindows(capabilities.atSpiAddress),
            fixture!,
          ),
        (windows) => windows.length === 1,
      );
      const initialWindow = initialFixtureWindows[0]!;

      await step(
        "Verify the launched fixture owns keyboard focus",
        async () => {
          await waitFor(
            "the initial fixture window to become active",
            async () =>
              fixtureWindows(
                await listAccessibleWindows(capabilities.atSpiAddress),
                fixture!,
              ),
            (windows) => windows.length === 1 && windows[0]?.active === true,
          );
          fixtureFocused = true;
        },
      );

      monitor = await startKeydMonitor(capabilities.keydBinary);
      await injectPhysicalChord(
        { keys: ["leftAlt", "n"] },
        capabilities.ydotoolSocket,
      );

      const resultingWindows = await waitFor(
        "exactly two fixture-owned Ghostty windows",
        async () =>
          fixtureWindows(
            await listAccessibleWindows(capabilities.atSpiAddress),
            fixture!,
          ),
        (windows) => windows.length === 2,
      );
      const newWindow = resultingWindows.find(
        (window) => !sameAccessibleRef(window.ref, initialWindow.ref),
      );
      if (newWindow === undefined) {
        throw new Error(
          `the second fixture window did not have a new AT-SPI identity: ${JSON.stringify(resultingWindows)}`,
        );
      }

      await waitFor(
        "the new fixture-owned Ghostty window to hold active keyboard focus",
        async () =>
          fixtureWindows(
            await listAccessibleWindows(capabilities.atSpiAddress),
            fixture!,
          ),
        (windows) =>
          windows.some(
            (window) =>
              window.active && sameAccessibleRef(window.ref, newWindow.ref),
          ),
      );

      const evidence = await waitForKeydChordEvidence(monitor);
      console.log(
        `  • keyd evidence retained: ${evidence
          .split("\n")
          .filter(
            (line) => line.includes("leftalt down") || line.includes("n down"),
          )
          .join(" | ")}`,
      );
    } catch (error) {
      originalFailure = error;
    }

    if (monitor !== undefined) {
      await cleanupAction(
        "Stop bounded keyd evidence capture",
        async () => stopKeydMonitor(monitor!),
        cleanupErrors,
      );
    }
    if (fixture !== undefined && fixtureLaunched) {
      await cleanupAction(
        "Stop the fixture-owned Ghostty unit",
        async () => stopFixture(fixture!),
        cleanupErrors,
      );
      await cleanupAction(
        "Confirm all fixture-owned Ghostty windows are gone",
        async () => {
          await waitFor(
            "zero fixture-owned Ghostty windows",
            async () =>
              fixtureWindows(
                await listAccessibleWindows(capabilities.atSpiAddress),
                fixture!,
              ),
            (windows) => windows.length === 0,
          );
        },
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
    if (fixture !== undefined) {
      await cleanupAction(
        "Remove the fixture runtime directory",
        async () => removeFixtureDirectory(fixture!),
        cleanupErrors,
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
      throw new AggregateError(cleanupErrors, "desktop E2E cleanup failed");
    }
  }, 40_000);
});
