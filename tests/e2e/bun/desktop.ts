export interface CommandResult {
  readonly command: readonly string[];
  readonly exitCode: number;
  readonly stderr: string;
  readonly stdout: string;
  readonly timedOut: boolean;
}

export interface CommandOptions {
  readonly check?: boolean;
  readonly cwd?: string;
  readonly env?: Readonly<Record<string, string | undefined>>;
  readonly timeoutMs?: number;
}

export interface AccessibleRef {
  readonly bus: string;
  readonly path: string;
}

export interface AccessibleWindow {
  readonly active: boolean;
  readonly app: AccessibleRef;
  readonly appId: string;
  readonly ref: AccessibleRef;
  readonly title: string;
}

interface BusctlEnvelope {
  readonly data: unknown;
  readonly type: string;
}

const desktopRoot: AccessibleRef = {
  bus: "org.a11y.atspi.Registry",
  path: "/org/a11y/atspi/accessible/root",
};

function displayCommand(command: readonly string[]): string {
  return command.map((part) => JSON.stringify(part)).join(" ");
}

function describeError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function describeObservation(value: unknown): string {
  if (typeof value === "string") {
    return JSON.stringify(value);
  }

  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

export async function runCommand(
  command: readonly string[],
  options: CommandOptions = {},
): Promise<CommandResult> {
  const timeoutMs = options.timeoutMs ?? 10_000;
  const process = Bun.spawn({
    cmd: [...command],
    ...(options.cwd === undefined ? {} : { cwd: options.cwd }),
    env: { ...Bun.env, ...options.env },
    stdout: "pipe",
    stderr: "pipe",
  });

  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    process.kill("SIGTERM");
  }, timeoutMs);

  const [exitCode, stdout, stderr] = await Promise.all([
    process.exited,
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
  ]);
  clearTimeout(timeout);

  const result: CommandResult = {
    command,
    exitCode,
    stderr,
    stdout,
    timedOut,
  };

  if ((options.check ?? true) && (timedOut || exitCode !== 0)) {
    throw new Error(
      [
        timedOut
          ? `command timed out after ${timeoutMs} ms`
          : `command exited ${exitCode}`,
        displayCommand(command),
        stderr.trim() === "" ? undefined : `stderr:\n${stderr.trimEnd()}`,
        stdout.trim() === "" ? undefined : `stdout:\n${stdout.trimEnd()}`,
      ]
        .filter((line) => line !== undefined)
        .join("\n"),
    );
  }

  return result;
}

export async function step<T>(
  description: string,
  action: () => Promise<T>,
): Promise<T> {
  const started = performance.now();
  console.log(`  → ${description}`);

  try {
    const result = await action();
    console.log(
      `  ✓ ${description} (${((performance.now() - started) / 1000).toFixed(2)}s)`,
    );
    return result;
  } catch (error) {
    console.error(
      `  ✗ ${description} (${((performance.now() - started) / 1000).toFixed(2)}s)`,
    );
    throw error;
  }
}

export function observationDelayMs(): number {
  const value = Bun.env.NIX_GARDEN_E2E_SLOW_SECONDS ?? "0";
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds < 0) {
    throw new Error(
      `NIX_GARDEN_E2E_SLOW_SECONDS must be non-negative, got ${JSON.stringify(value)}`,
    );
  }
  return seconds * 1_000;
}

export async function holdFailureForInspection(scope: string): Promise<void> {
  const delayMs = observationDelayMs();
  if (delayMs === 0) {
    return;
  }
  console.error(
    `    ! INSPECT FAILURE (${delayMs / 1_000}s): ${scope}; cleanup is paused`,
  );
  await Bun.sleep(delayMs);
}

export async function waitFor<T>(
  description: string,
  observe: () => Promise<T>,
  accept: (value: T) => boolean,
  options: { readonly intervalMs?: number; readonly timeoutMs?: number } = {},
): Promise<T> {
  const intervalMs = options.intervalMs ?? 100;
  const timeoutMs = options.timeoutMs ?? 10_000;
  const started = performance.now();
  let attempts = 0;
  let lastError: unknown;
  let lastObserved: T | undefined;

  console.log(`    … Waiting for ${description}`);

  while (performance.now() - started < timeoutMs) {
    attempts += 1;
    try {
      lastObserved = await observe();
      lastError = undefined;
      if (accept(lastObserved)) {
        return lastObserved;
      }
    } catch (error) {
      lastError = error;
    }

    await new Promise<void>((resolve) => setTimeout(resolve, intervalMs));
  }

  throw new Error(
    [
      `timed out after ${timeoutMs} ms waiting for ${description}`,
      `attempts: ${attempts}`,
      `last observed: ${describeObservation(lastObserved)}`,
      lastError === undefined
        ? undefined
        : `last observation error: ${describeError(lastError)}`,
    ]
      .filter((line) => line !== undefined)
      .join("\n"),
  );
}

export async function waitForExactOutput(
  command: readonly string[],
  expected: string,
  timeoutMs = 10_000,
): Promise<void> {
  await waitFor(
    `exact output ${JSON.stringify(expected)} from ${displayCommand(command)}`,
    async () =>
      (await runCommand(command, { check: false, timeoutMs: 2_000 })).stdout,
    (stdout) => stdout === expected,
    { timeoutMs },
  );
}

function parseEnvelope(
  stdout: string,
  command: readonly string[],
): BusctlEnvelope {
  let value: unknown;
  try {
    value = JSON.parse(stdout);
  } catch (error) {
    throw new Error(
      `invalid JSON from ${displayCommand(command)}: ${describeError(error)}\n${stdout}`,
    );
  }

  if (
    typeof value !== "object" ||
    value === null ||
    !("type" in value) ||
    typeof value.type !== "string" ||
    !("data" in value)
  ) {
    throw new Error(
      `unexpected busctl envelope from ${displayCommand(command)}: ${stdout}`,
    );
  }

  return value as BusctlEnvelope;
}

async function busctlJson(command: readonly string[]): Promise<BusctlEnvelope> {
  const result = await runCommand(command);
  return parseEnvelope(result.stdout, command);
}

function singleString(envelope: BusctlEnvelope, context: string): string {
  if (typeof envelope.data === "string") {
    return envelope.data;
  }

  if (
    Array.isArray(envelope.data) &&
    envelope.data.length === 1 &&
    typeof envelope.data[0] === "string"
  ) {
    return envelope.data[0];
  }

  throw new Error(`${context} returned ${describeObservation(envelope)}`);
}

function accessibleRefs(
  envelope: BusctlEnvelope,
  context: string,
): AccessibleRef[] {
  if (
    !Array.isArray(envelope.data) ||
    envelope.data.length !== 1 ||
    !Array.isArray(envelope.data[0])
  ) {
    throw new Error(`${context} returned ${describeObservation(envelope)}`);
  }

  return envelope.data[0].map((value: unknown) => {
    if (
      !Array.isArray(value) ||
      value.length !== 2 ||
      typeof value[0] !== "string" ||
      typeof value[1] !== "string"
    ) {
      throw new Error(`${context} contained ${describeObservation(value)}`);
    }

    return { bus: value[0], path: value[1] };
  });
}

function stateWords(envelope: BusctlEnvelope, context: string): number[] {
  if (
    !Array.isArray(envelope.data) ||
    envelope.data.length !== 1 ||
    !Array.isArray(envelope.data[0]) ||
    !envelope.data[0].every((value) => typeof value === "number")
  ) {
    throw new Error(`${context} returned ${describeObservation(envelope)}`);
  }

  return envelope.data[0] as number[];
}

function hasState(words: readonly number[], state: number): boolean {
  const word = words[Math.floor(state / 32)] ?? 0;
  return (word & (1 << (state % 32))) !== 0;
}

export async function accessibleSubtreeHasFocus(
  address: string,
  root: AccessibleRef,
): Promise<boolean> {
  const pending = [root];
  const visited = new Set<string>();

  while (pending.length > 0) {
    const ref = pending.shift()!;
    const key = `${ref.bus}\0${ref.path}`;
    if (visited.has(key)) {
      continue;
    }
    visited.add(key);

    try {
      const [states, children] = await Promise.all([
        callAtSpi(address, ref, "org.a11y.atspi.Accessible", "GetState").then(
          (envelope) =>
            stateWords(envelope, `AT-SPI state for ${ref.bus}${ref.path}`),
        ),
        getChildren(address, ref),
      ]);
      if (hasState(states, 12)) {
        return true;
      }
      pending.push(...children);
    } catch {
      // Descendants may disappear while Chromium rebuilds its accessibility tree.
    }
  }

  return false;
}

async function callAtSpi(
  address: string,
  ref: AccessibleRef,
  interfaceName: string,
  method: string,
): Promise<BusctlEnvelope> {
  return busctlJson([
    "busctl",
    `--address=${address}`,
    "--json=short",
    "call",
    ref.bus,
    ref.path,
    interfaceName,
    method,
  ]);
}

async function getAtSpiProperty(
  address: string,
  ref: AccessibleRef,
  property: string,
): Promise<BusctlEnvelope> {
  return busctlJson([
    "busctl",
    `--address=${address}`,
    "--json=short",
    "get-property",
    ref.bus,
    ref.path,
    "org.a11y.atspi.Accessible",
    property,
  ]);
}

async function getChildren(
  address: string,
  ref: AccessibleRef,
): Promise<AccessibleRef[]> {
  return accessibleRefs(
    await callAtSpi(address, ref, "org.a11y.atspi.Accessible", "GetChildren"),
    `AT-SPI children for ${ref.bus}${ref.path}`,
  );
}

export async function getAtSpiAddress(): Promise<string> {
  const command = [
    "busctl",
    "--user",
    "--json=short",
    "call",
    "org.a11y.Bus",
    "/org/a11y/bus",
    "org.a11y.Bus",
    "GetAddress",
  ];
  return singleString(await busctlJson(command), "AT-SPI bus address");
}

export async function listAccessibleWindows(
  address: string,
): Promise<AccessibleWindow[]> {
  const applications = await getChildren(address, desktopRoot);
  const windows: AccessibleWindow[] = [];

  for (const app of applications) {
    try {
      const appId = singleString(
        await getAtSpiProperty(address, app, "AccessibleId"),
        `AT-SPI application id for ${app.bus}`,
      );
      const children = await getChildren(address, app);

      for (const ref of children) {
        const role = singleString(
          await callAtSpi(
            address,
            ref,
            "org.a11y.atspi.Accessible",
            "GetRoleName",
          ),
          `AT-SPI role for ${ref.bus}${ref.path}`,
        );
        if (role !== "window" && role !== "frame") {
          continue;
        }

        const title = singleString(
          await getAtSpiProperty(address, ref, "Name"),
          `AT-SPI title for ${ref.bus}${ref.path}`,
        );
        const states = stateWords(
          await callAtSpi(
            address,
            ref,
            "org.a11y.atspi.Accessible",
            "GetState",
          ),
          `AT-SPI state for ${ref.bus}${ref.path}`,
        );

        windows.push({
          active: hasState(states, 1),
          app,
          appId,
          ref,
          title,
        });
      }
    } catch {
      // Applications and windows may disappear while the registry is read.
      // A bounded caller retries when a complete state matters.
    }
  }

  return windows;
}

export async function focusAccessibleWindow(
  address: string,
  window: AccessibleWindow,
): Promise<void> {
  const envelope = await callAtSpi(
    address,
    window.ref,
    "org.a11y.atspi.Component",
    "GrabFocus",
  );
  if (
    !Array.isArray(envelope.data) ||
    envelope.data.length !== 1 ||
    envelope.data[0] !== true
  ) {
    throw new Error(
      `AT-SPI refused focus for ${window.appId} ${JSON.stringify(window.title)}: ${describeObservation(envelope)}`,
    );
  }
}

export function sameAccessibleRef(
  left: AccessibleRef,
  right: AccessibleRef,
): boolean {
  return left.bus === right.bus && left.path === right.path;
}

export function errorMessage(error: unknown): string {
  return describeError(error);
}
