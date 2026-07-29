import { observationDelayMs, runCommand, step, waitFor } from "./desktop.ts";

export type PhysicalKey =
  | "a"
  | "c"
  | "d"
  | "enter"
  | "leftAlt"
  | "leftBracket"
  | "leftCtrl"
  | "leftShift"
  | "l"
  | "n"
  | "q"
  | "rightBracket"
  | "tab"
  | "t"
  | "v"
  | "w";

const keyCodes: Readonly<Record<PhysicalKey, number>> = {
  a: 30,
  c: 46,
  d: 32,
  enter: 28,
  leftAlt: 56,
  leftBracket: 26,
  leftCtrl: 29,
  leftShift: 42,
  l: 38,
  n: 49,
  q: 16,
  rightBracket: 27,
  tab: 15,
  t: 20,
  v: 47,
  w: 17,
};

const displayNames: Readonly<Record<PhysicalKey, string>> = {
  a: "A",
  c: "C",
  d: "D",
  enter: "Enter",
  leftAlt: "Alt",
  leftBracket: "[",
  leftCtrl: "Ctrl",
  leftShift: "Shift",
  l: "L",
  n: "N",
  q: "Q",
  rightBracket: "]",
  tab: "Tab",
  t: "T",
  v: "V",
  w: "W",
};

const evidenceNames: Readonly<Record<PhysicalKey, string>> = {
  a: "a",
  c: "c",
  d: "d",
  enter: "enter",
  leftAlt: "leftalt",
  leftBracket: "[",
  leftCtrl: "leftcontrol",
  leftShift: "leftshift",
  l: "l",
  n: "n",
  q: "q",
  rightBracket: "]",
  tab: "tab",
  t: "t",
  v: "v",
  w: "w",
};

export interface KeydMonitor {
  readonly evidence: () => string;
  readonly stop: () => Promise<void>;
}

export interface PhysicalChord {
  readonly keys: readonly [PhysicalKey, ...PhysicalKey[]];
}

export interface InjectionOptions {
  readonly watch?: string;
}

export async function startKeydMonitor(
  keydBinary: string,
): Promise<KeydMonitor> {
  return step("Start bounded keyd evidence capture through sudo", async () => {
    const process = Bun.spawn({
      cmd: ["sudo", "-n", keydBinary, "monitor", "-t"],
      env: Bun.env,
      stdout: "pipe",
      stderr: "pipe",
    });
    const decoder = new TextDecoder();
    let output = "";
    const readOutput = (async () => {
      const reader = process.stdout.getReader();
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) {
          output += decoder.decode();
          return;
        }
        output += decoder.decode(chunk.value, { stream: true });
      }
    })();

    const monitor: KeydMonitor = {
      evidence: () => output,
      stop: async () => {
        if (process.exitCode === null) {
          process.kill("SIGTERM");
        }
        await process.exited;
        await readOutput;
      },
    };

    await waitFor(
      "keyd monitor to attach to the ydotool virtual keyboard",
      async () => ({
        evidence: monitor.evidence(),
        exitCode: process.exitCode,
      }),
      (state) =>
        state.exitCode === null &&
        state.evidence
          .split("\n")
          .some(
            (line) =>
              line.includes("device added:") &&
              line.includes("ydotoold virtual device"),
          ),
      { timeoutMs: 5_000 },
    );

    return monitor;
  });
}

export async function stopKeydMonitor(monitor: KeydMonitor): Promise<void> {
  await monitor.stop();
}

export async function injectPhysicalChord(
  chord: PhysicalChord,
  ydotoolSocket: string,
  options: InjectionOptions = {},
): Promise<void> {
  const label = chord.keys.map((key) => displayNames[key]).join("+");
  await step(`Inject physical ${label} before keyd`, async () => {
    const delayMs = observationDelayMs();
    if (delayMs > 0 && options.watch !== undefined) {
      console.log(
        `    • WATCH NOW: ${options.watch} (${delayMs / 1_000}s after injection)`,
      );
    }
    const presses = chord.keys.map((key) => `${keyCodes[key]}:1`);
    const releases = [...chord.keys]
      .reverse()
      .map((key) => `${keyCodes[key]}:0`);
    await runCommand(["ydotool", "key", ...presses, ...releases], {
      env: { YDOTOOL_SOCKET: ydotoolSocket },
    });
    if (delayMs > 0 && options.watch !== undefined) {
      await Bun.sleep(delayMs);
    }
  });
}

export async function injectPhysicalText(
  text: string,
  ydotoolSocket: string,
): Promise<void> {
  await step("Type fixture text before keyd", async () => {
    await runCommand(["ydotool", "type", text], {
      env: { YDOTOOL_SOCKET: ydotoolSocket },
    });
  });
}

export async function waitForKeydChordEvidence(
  monitor: KeydMonitor,
  chord: PhysicalChord,
  since = 0,
): Promise<string> {
  const label = chord.keys.map((key) => displayNames[key]).join("+");
  const expected = chord.keys.map((key) => `${evidenceNames[key]} down`);
  return waitFor(
    `keyd monitor to report ${label} evidence`,
    async () => monitor.evidence().slice(since),
    (evidence) => expected.every((event) => evidence.includes(event)),
    { timeoutMs: 5_000 },
  );
}
