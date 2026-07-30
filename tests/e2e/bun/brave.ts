// Brave E2E plumbing: launch lineage, the isolated fixture (HTTP server, Brave
// process, DevTools/CDP access), GNOME toolkit-accessibility, and cleanup. The
// behavioral scenario lives in brave.test.ts and reads as a sequence of chords
// and expected outcomes; the mechanics that make that possible live here.

import { readFileSync } from "node:fs";
import {
  type AccessibleWindow,
  errorMessage,
  note,
  runCommand,
  sameAccessibleRef,
  step,
  waitFor,
} from "./desktop.ts";

const toolkitAccessibilityKey =
  "/org/gnome/desktop/interface/toolkit-accessibility";

interface ProcessAncestor {
  readonly command: string;
  readonly pid: number;
  readonly parentPid: number;
}

function processAncestry(): ProcessAncestor[] {
  const ancestors: ProcessAncestor[] = [];
  const visited = new Set<number>();
  let pid = process.pid;

  while (pid > 0 && !visited.has(pid) && ancestors.length < 64) {
    visited.add(pid);
    let status: string;
    let commandLine: string;
    try {
      status = readFileSync(`/proc/${pid}/status`, "utf8");
      commandLine = readFileSync(`/proc/${pid}/cmdline`, "utf8");
    } catch {
      break;
    }
    const parentMatch = /^PPid:\s+([0-9]+)$/m.exec(status);
    if (parentMatch?.[1] === undefined) {
      break;
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

export type BraveLineage =
  { readonly ok: true } | { readonly ok: false; readonly reason: string };

// Brave alone needs a visible Ghostty-rooted invoker to launch a focus-eligible
// native Wayland window; a Herdr-rooted or detached lineage cannot. Because this
// is a Brave-only constraint, an ineligible lineage skips the Brave test rather
// than failing the suite, so every other test — and any new one — still runs
// (e.g. when driving from a Herdr session on the host).
export function braveLaunchLineage(): BraveLineage {
  const ancestors = processAncestry();
  const commands = ancestors.map((ancestor) => ancestor.command.toLowerCase());
  const chain = ancestors
    .map((ancestor) => `${ancestor.pid}:${ancestor.command}`)
    .join(" <- ");

  if (commands.some((command) => command.includes("herdr"))) {
    return { ok: false, reason: `Herdr-rooted lineage: ${chain}` };
  }
  if (!commands.some((command) => command.includes("ghostty"))) {
    return { ok: false, reason: `no visible Ghostty-rooted lineage: ${chain}` };
  }
  return { ok: true };
}

export type ToolkitAccessibilityBaseline = "false" | "true" | "unset";

export async function toolkitAccessibility(): Promise<ToolkitAccessibilityBaseline> {
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

export async function setToolkitAccessibility(
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

export async function createFixture() {
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
      const pageTitle = `${title}-${pageName}`;
      const body =
        pageName === "initial"
          ? `<main style="font:24px sans-serif;padding:2rem"><h1>Brave clipboard E2E</h1><p>Expected after Alt+V: <strong>PASTE_PROBE</strong></p><label for="target">Current textarea value:</label><br><textarea id="target" autofocus style="font:28px monospace;margin-top:0.5rem;padding:1rem;width:32rem">COPY_PROBE</textarea><p id="status">Waiting for mapped Alt+V</p></main><script>const target=document.getElementById("target");const status=document.getElementById("status");target.focus();target.select();target.addEventListener("input",()=>{document.title=${JSON.stringify(`${pageTitle}-`)}+target.value;status.textContent=target.value==="PASTE_PROBE"?"PASS: textarea contains PASTE_PROBE":\`Observed: \${target.value}\`;});document.addEventListener("copy",()=>{window.__copyCount=(window.__copyCount||0)+1;window.__lastCopy=target.value.substring(target.selectionStart,target.selectionEnd);});</script>`
          : `BRAVE_${pageName.toUpperCase()}_PROBE`;
      return new Response(
        `<!doctype html><html><head><title>${pageTitle}</title></head><body>${body}</body></html>`,
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

export type BraveFixture = Awaited<ReturnType<typeof createFixture>>;

export function fixtureWindows(
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

export function launchFixture(fixture: BraveFixture) {
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

export type BraveProcess = ReturnType<typeof launchFixture>;

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

export async function stopFixture(
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

export async function removeFixtureDirectory(
  fixture: BraveFixture,
): Promise<void> {
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

export async function devToolsPort(fixture: BraveFixture): Promise<number> {
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

export interface DevToolsPage {
  readonly id: string;
  readonly title: string;
  readonly url: string;
  readonly webSocketDebuggerUrl: string;
}

export async function pages(port: number): Promise<DevToolsPage[]> {
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
      !("title" in target) ||
      typeof target.title !== "string" ||
      !("url" in target) ||
      typeof target.url !== "string" ||
      !("webSocketDebuggerUrl" in target) ||
      typeof target.webSocketDebuggerUrl !== "string"
    ) {
      throw new Error("DevTools page target was incomplete");
    }
    pages.push({
      id: target.id,
      title: target.title,
      url: target.url,
      webSocketDebuggerUrl: target.webSocketDebuggerUrl,
    });
  }

  return pages;
}

export async function waitForPageCount(
  port: number,
  expected: number,
): Promise<DevToolsPage[]> {
  return waitFor(
    `${expected} isolated Brave DevTools page${expected === 1 ? "" : "s"}`,
    async () => pages(port),
    (observed) => observed.length === expected,
  );
}

export async function waitForPageUrl(
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

export async function waitForPageTitle(
  port: number,
  id: string,
  title: string,
): Promise<void> {
  await waitFor(
    `DevTools page ${id} to expose title ${JSON.stringify(title)}`,
    async () => pages(port),
    (pages) => pages.some((page) => page.id === id && page.title === title),
  );
}

interface EvaluateOptions {
  readonly awaitPromise?: boolean;
  readonly userGesture?: boolean;
}

async function evaluateValue(
  page: DevToolsPage,
  expression: string,
  options: EvaluateOptions = {},
): Promise<unknown> {
  return new Promise<unknown>((resolve, reject) => {
    const socket = new WebSocket(page.webSocketDebuggerUrl);
    let settled = false;
    const finish = (result: unknown, error?: Error): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeout);
      socket.close();
      if (error !== undefined) {
        reject(error);
      } else {
        resolve(result);
      }
    };
    const timeout = setTimeout(
      () =>
        finish(
          undefined,
          new Error("CDP Runtime.evaluate timed out after 2000 ms"),
        ),
      2_000,
    );

    socket.addEventListener("open", () => {
      socket.send(
        JSON.stringify({
          id: 1,
          method: "Runtime.evaluate",
          params: {
            expression,
            returnByValue: true,
            awaitPromise: options.awaitPromise ?? false,
            userGesture: options.userGesture ?? false,
          },
        }),
      );
    });
    socket.addEventListener("error", () => {
      finish(undefined, new Error("CDP Runtime.evaluate WebSocket failed"));
    });
    socket.addEventListener("message", (event) => {
      let envelope: unknown;
      try {
        envelope = JSON.parse(String(event.data));
      } catch {
        finish(
          undefined,
          new Error("CDP Runtime.evaluate returned invalid JSON"),
        );
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
        finish(undefined, new Error("CDP Runtime.evaluate returned an error"));
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
      finish(value);
    });
  });
}

export async function evaluateBoolean(
  page: DevToolsPage,
  expression: string,
): Promise<boolean> {
  const value = await evaluateValue(page, expression);
  if (typeof value !== "boolean") {
    throw new Error("CDP Runtime.evaluate returned no boolean value");
  }
  return value;
}

export async function documentHasFocus(page: DevToolsPage): Promise<boolean> {
  return evaluateBoolean(page, "document.hasFocus()");
}

// Seed the clipboard from inside the already-focused Brave page. Unlike an
// external wl-copy/wl-paste client, this never introduces a foreign window, so
// the keyd application-mapper keeps its Brave context and Alt+V stays mapped.
export async function seedClipboard(
  page: DevToolsPage,
  text: string,
): Promise<void> {
  const value = await evaluateValue(
    page,
    `navigator.clipboard.writeText(${JSON.stringify(text)}).then(() => true).catch((error) => String((error && error.message) || error))`,
    { awaitPromise: true, userGesture: true },
  );
  if (value !== true) {
    throw new Error(
      `CDP clipboard seed failed: ${typeof value === "string" ? value : JSON.stringify(value)}`,
    );
  }
}

export async function focusFixtureTextarea(
  page: DevToolsPage,
): Promise<boolean> {
  return evaluateBoolean(
    page,
    '(() => { const target = document.getElementById("target"); if (!(target instanceof HTMLTextAreaElement)) return false; target.focus(); target.select(); return document.hasFocus() && document.activeElement === target; })()',
  );
}

export async function cleanupAction(
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
    note(`! cleanup may be incomplete: ${cleanupError.message}`);
  }
}
