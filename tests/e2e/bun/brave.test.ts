import { afterAll, beforeAll, describe, test } from "bun:test";
import {
  accessibleSubtreeHasFocus,
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
  injectPhysicalText,
  type KeydMonitor,
  startKeydMonitor,
  stopKeydMonitor,
  waitForKeydChordEvidence,
} from "./keyboard.ts";
import { type Capabilities, validateCapabilities } from "./setup.ts";

let capabilities: Capabilities;

const toolkitAccessibilityKey =
  "/org/gnome/desktop/interface/toolkit-accessibility";

interface ProcessAncestor {
  readonly command: string;
  readonly pid: number;
  readonly parentPid: number;
}

async function processAncestry(): Promise<ProcessAncestor[]> {
  const ancestors: ProcessAncestor[] = [];
  const visited = new Set<number>();
  let pid = process.pid;

  while (pid > 0 && !visited.has(pid) && ancestors.length < 64) {
    visited.add(pid);
    const [status, commandLine] = await Promise.all([
      Bun.file(`/proc/${pid}/status`).text(),
      Bun.file(`/proc/${pid}/cmdline`).text(),
    ]);
    const parentMatch = /^PPid:\s+([0-9]+)$/m.exec(status);
    if (parentMatch?.[1] === undefined) {
      throw new Error(`could not resolve parent PID for process ${pid}`);
    }
    const parentPid = Number(parentMatch[1]);
    const executable = commandLine.split("\0")[0];
    const command =
      executable === undefined || executable === ""
        ? "(exited)"
        : executable.slice(executable.lastIndexOf("/") + 1);
    ancestors.push({ command, parentPid, pid });
    pid = parentPid;
  }

  return ancestors;
}

async function validateLaunchLineage(): Promise<void> {
  const ancestors = await processAncestry();
  const commands = ancestors.map((ancestor) => ancestor.command.toLowerCase());
  const chain = ancestors
    .map((ancestor) => `${ancestor.pid}:${ancestor.command}`)
    .join(" <- ");

  if (commands.some((command) => command.includes("herdr"))) {
    throw new Error(
      `Brave E2E refuses a Herdr-rooted process lineage: ${chain}`,
    );
  }
  if (!commands.some((command) => command.includes("ghostty"))) {
    throw new Error(
      `Brave E2E requires a visible Ghostty-rooted process lineage: ${chain}`,
    );
  }
}

type ToolkitAccessibilityBaseline = "false" | "true" | "unset";

async function toolkitAccessibility(): Promise<ToolkitAccessibilityBaseline> {
  const value = (
    await runCommand(["dconf", "read", toolkitAccessibilityKey])
  ).stdout.trim();
  if (value === "") {
    return "unset";
  }
  if (value !== "true" && value !== "false") {
    throw new Error(
      `unexpected GNOME toolkit-accessibility value ${JSON.stringify(value)}`,
    );
  }

  return value;
}

async function setToolkitAccessibility(
  value: ToolkitAccessibilityBaseline,
): Promise<void> {
  if (value === "unset") {
    await runCommand(["dconf", "reset", toolkitAccessibilityKey]);
  } else {
    await runCommand(["dconf", "write", toolkitAccessibilityKey, value]);
  }
  await waitFor(
    `GNOME toolkit-accessibility baseline to become ${value}`,
    toolkitAccessibility,
    (observed) => observed === value,
  );
}

async function createFixture() {
  const runtimeDirectory = Bun.env.XDG_RUNTIME_DIR;
  if (runtimeDirectory === undefined) {
    throw new Error("XDG_RUNTIME_DIR is unavailable");
  }

  const directory = (
    await runCommand([
      "mktemp",
      "--directory",
      `${runtimeDirectory}/nix-garden-e2e-brave.XXXXXX`,
    ])
  ).stdout.trim();
  const runId = directory.slice(directory.lastIndexOf(".") + 1);
  const title = `nix-garden-e2e-brave-${runId}`;
  const server = Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    fetch(request) {
      const pathname = new URL(request.url).pathname;
      const pageName = pathname === "/" ? "initial" : pathname.slice(1);
      return new Response(
        `<!doctype html><html><head><title>${title}-${pageName}</title></head><body>BRAVE_${pageName.toUpperCase()}_PROBE</body></html>`,
        { headers: { "content-type": "text/html; charset=utf-8" } },
      );
    },
  });

  return {
    directory,
    profileDirectory: `${directory}/profile`,
    server,
    title,
    url: `http://127.0.0.1:${server.port}/`,
    navigationUrl: `http://127.0.0.1:${server.port}/navigation`,
    addressUrl: `http://127.0.0.1:${server.port}/address`,
  };
}

type BraveFixture = Awaited<ReturnType<typeof createFixture>>;

function fixtureWindows(
  windows: readonly AccessibleWindow[],
  fixture: BraveFixture,
  application: AccessibleWindow["app"] | undefined,
): AccessibleWindow[] {
  if (application !== undefined) {
    return windows.filter((window) =>
      sameAccessibleRef(window.app, application),
    );
  }

  return windows.filter((window) => window.title.startsWith(fixture.title));
}

function launchFixture(fixture: BraveFixture) {
  return Bun.spawn({
    cmd: [
      "brave",
      `--user-data-dir=${fixture.profileDirectory}`,
      "--remote-debugging-address=127.0.0.1",
      "--remote-debugging-port=0",
      "--remote-allow-origins=*",
      "--force-renderer-accessibility",
      "--disable-background-mode",
      "--no-first-run",
      "--no-default-browser-check",
      "--password-store=basic",
      fixture.url,
    ],
    env: Bun.env,
    stdin: "ignore",
    stdout: "ignore",
    stderr: "ignore",
  });
}

type BraveProcess = ReturnType<typeof launchFixture>;

async function waitForProcessExit(
  process: BraveProcess,
  timeoutMs: number,
): Promise<void> {
  await Promise.race([
    process.exited.then(() => undefined),
    Bun.sleep(timeoutMs).then(() => {
      throw new Error(`Brave parent did not exit after ${timeoutMs} ms`);
    }),
  ]);
}

async function stopFixture(
  fixture: BraveFixture,
  process: BraveProcess,
  port: number | undefined,
): Promise<void> {
  if (port !== undefined) {
    try {
      for (const page of await pages(port)) {
        await fetch(
          `http://127.0.0.1:${port}/json/close/${encodeURIComponent(page.id)}`,
          { signal: AbortSignal.timeout(2_000) },
        );
      }
    } catch {
      // Parent-process termination below remains the bounded fallback.
    }
  }

  if (process.exitCode === null) {
    process.kill("SIGTERM");
  }
  try {
    await waitForProcessExit(process, 3_000);
  } catch {
    if (process.exitCode === null) {
      process.kill("SIGKILL");
    }
    await waitForProcessExit(process, 3_000);
  }

  await waitFor(
    "zero Brave processes using the isolated profile",
    async () =>
      runCommand(["pgrep", "--full", "--", fixture.profileDirectory], {
        check: false,
      }),
    (result) => result.exitCode === 1,
    { timeoutMs: 5_000 },
  );
}

async function removeFixtureDirectory(fixture: BraveFixture): Promise<void> {
  const runtimeDirectory = Bun.env.XDG_RUNTIME_DIR;
  const expectedPrefix = `${runtimeDirectory}/nix-garden-e2e-brave.`;
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

async function devToolsPort(fixture: BraveFixture): Promise<number> {
  const port = await waitFor(
    "Brave to publish its isolated DevTools port",
    async () => {
      const firstLine = (
        await Bun.file(`${fixture.profileDirectory}/DevToolsActivePort`).text()
      )
        .split("\n")
        .at(0);
      return firstLine !== undefined && /^[0-9]+$/.test(firstLine)
        ? Number(firstLine)
        : undefined;
    },
    (port): port is number => port !== undefined,
  );
  if (port === undefined) {
    throw new Error("Brave published no usable DevTools port");
  }

  return port;
}

interface DevToolsPage {
  readonly id: string;
  readonly url: string;
  readonly webSocketDebuggerUrl: string;
}

async function pages(port: number): Promise<DevToolsPage[]> {
  const response = await fetch(`http://127.0.0.1:${port}/json/list`, {
    signal: AbortSignal.timeout(2_000),
  });
  if (!response.ok) {
    throw new Error(`DevTools page list returned HTTP ${response.status}`);
  }

  const targets: unknown = await response.json();
  if (!Array.isArray(targets)) {
    throw new Error("DevTools page list was not an array");
  }

  const pages: DevToolsPage[] = [];
  for (const target of targets) {
    if (
      typeof target !== "object" ||
      target === null ||
      !("type" in target) ||
      target.type !== "page"
    ) {
      continue;
    }
    if (
      !("id" in target) ||
      typeof target.id !== "string" ||
      !("url" in target) ||
      typeof target.url !== "string" ||
      !("webSocketDebuggerUrl" in target) ||
      typeof target.webSocketDebuggerUrl !== "string"
    ) {
      throw new Error("DevTools page target was incomplete");
    }
    pages.push({
      id: target.id,
      url: target.url,
      webSocketDebuggerUrl: target.webSocketDebuggerUrl,
    });
  }

  return pages;
}

async function waitForPageCount(
  port: number,
  expected: number,
): Promise<DevToolsPage[]> {
  return waitFor(
    `${expected} isolated Brave DevTools page${expected === 1 ? "" : "s"}`,
    async () => pages(port),
    (observed) => observed.length === expected,
  );
}

async function waitForPageUrl(
  port: number,
  id: string,
  url: string,
): Promise<DevToolsPage> {
  const observed = await waitFor(
    `DevTools page ${id} to load ${JSON.stringify(url)}`,
    async () => pages(port),
    (pages) => pages.some((page) => page.id === id && page.url === url),
  );
  const page = observed.find(
    (candidate) => candidate.id === id && candidate.url === url,
  );
  if (page === undefined) {
    throw new Error(`DevTools page ${id} disappeared after navigation`);
  }
  return page;
}

async function documentHasFocus(page: DevToolsPage): Promise<boolean> {
  return new Promise<boolean>((resolve, reject) => {
    const socket = new WebSocket(page.webSocketDebuggerUrl);
    let settled = false;
    const finish = (result: boolean | Error): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeout);
      socket.close();
      if (result instanceof Error) {
        reject(result);
      } else {
        resolve(result);
      }
    };
    const timeout = setTimeout(
      () => finish(new Error("CDP Runtime.evaluate timed out after 2000 ms")),
      2_000,
    );

    socket.addEventListener("open", () => {
      socket.send(
        JSON.stringify({
          id: 1,
          method: "Runtime.evaluate",
          params: {
            expression: "document.hasFocus()",
            returnByValue: true,
          },
        }),
      );
    });
    socket.addEventListener("error", () => {
      finish(new Error("CDP Runtime.evaluate WebSocket failed"));
    });
    socket.addEventListener("message", (event) => {
      let envelope: unknown;
      try {
        envelope = JSON.parse(String(event.data));
      } catch {
        finish(new Error("CDP Runtime.evaluate returned invalid JSON"));
        return;
      }
      if (
        typeof envelope !== "object" ||
        envelope === null ||
        !("id" in envelope) ||
        envelope.id !== 1
      ) {
        return;
      }
      if ("error" in envelope) {
        finish(new Error("CDP Runtime.evaluate returned an error"));
        return;
      }
      const value =
        "result" in envelope &&
        typeof envelope.result === "object" &&
        envelope.result !== null &&
        "result" in envelope.result &&
        typeof envelope.result.result === "object" &&
        envelope.result.result !== null &&
        "value" in envelope.result.result
          ? envelope.result.result.value
          : undefined;
      if (typeof value !== "boolean") {
        finish(new Error("CDP Runtime.evaluate returned no boolean value"));
        return;
      }
      finish(value);
    });
  });
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

describe("deployed Brave keyboard behavior", () => {
  test("physical Brave lifecycle and navigation chords traverse keyd", async () => {
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
    let monitor: KeydMonitor | undefined;
    let originalFailure: unknown;
    const cleanupErrors: Error[] = [];

    try {
      await step(
        "Validate Brave launch lineage from visible Ghostty",
        validateLaunchLineage,
      );

      const initialDesktop = await listAccessibleWindows(
        capabilities.atSpiAddress,
      );
      baseline = initialDesktop.find((window) => window.active);
      if (baseline === undefined) {
        throw new Error("AT-SPI reported no active baseline window");
      }

      accessibilityBaseline = await step(
        "Capture the GNOME toolkit-accessibility baseline",
        toolkitAccessibility,
      );
      if (accessibilityBaseline !== "true") {
        restoreToolkitAccessibility = true;
        await step("Temporarily enable GNOME toolkit accessibility", async () =>
          setToolkitAccessibility("true"),
        );
      }

      fixture = await step("Create the isolated Brave fixture", createFixture);
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
        throw new Error("DevTools did not report the exact local fixture page");
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
        "the initial Brave page to retain document focus before Alt+N",
        async () => documentHasFocus(initialPage),
        (focused) => focused,
      );
      await injectPhysicalChord(
        { keys: ["leftAlt", "n"] },
        capabilities.ydotoolSocket,
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
      await waitForKeydChordEvidence(monitor, { keys: ["leftAlt", "n"] });

      await waitFor(
        "keyboard focus to remain inside the new Brave frame before Alt+W",
        async () =>
          accessibleSubtreeHasFocus(capabilities.atSpiAddress, newWindow.ref),
        (focused) => focused,
      );
      await injectPhysicalChord(
        { keys: ["leftAlt", "w"] },
        capabilities.ydotoolSocket,
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
      await waitForKeydChordEvidence(monitor, { keys: ["leftAlt", "w"] });

      await injectPhysicalChord(
        { keys: ["leftAlt", "t"] },
        capabilities.ydotoolSocket,
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
      await waitForKeydChordEvidence(monitor, { keys: ["leftAlt", "t"] });

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

      await injectPhysicalChord(
        { keys: ["leftAlt", "l"] },
        capabilities.ydotoolSocket,
      );
      await waitForKeydChordEvidence(monitor, { keys: ["leftAlt", "l"] });
      await waitFor(
        "Alt+L to retain keyboard focus inside the fixture-owned Brave frame",
        async () =>
          accessibleSubtreeHasFocus(
            capabilities.atSpiAddress,
            initialWindow.ref,
          ),
        (focused) => focused,
      );
      await injectPhysicalText(fixture.addressUrl, capabilities.ydotoolSocket);
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

      const previousTabEvidence = monitor.evidence().length;
      await injectPhysicalChord(
        { keys: ["leftAlt", "leftShift", "leftBracket"] },
        capabilities.ydotoolSocket,
      );
      await waitFor(
        "Alt+Shift+[ to select the initial Brave tab",
        async () => documentHasFocus(initialPage),
        (focused) => focused,
      );
      await waitForKeydChordEvidence(
        monitor,
        {
          keys: ["leftCtrl", "leftShift", "tab"],
        },
        previousTabEvidence,
      );

      const nextTabEvidence = monitor.evidence().length;
      await injectPhysicalChord(
        { keys: ["leftAlt", "leftShift", "rightBracket"] },
        capabilities.ydotoolSocket,
      );
      await waitFor(
        "Alt+Shift+] to select the address-navigated Brave tab",
        async () => documentHasFocus(selectedTab),
        (focused) => focused,
      );
      await waitForKeydChordEvidence(
        monitor,
        {
          keys: ["leftCtrl", "tab"],
        },
        nextTabEvidence,
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
  }, 40_000);
});
