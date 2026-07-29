import { runCommand, step, waitFor } from "./desktop.ts";

export type PhysicalKey =
  | "c"
  | "d"
  | "leftAlt"
  | "leftBracket"
  | "leftCtrl"
  | "leftShift"
  | "n"
  | "q"
  | "rightBracket"
  | "t"
  | "w";

const keyCodes: Readonly<Record<PhysicalKey, number>> = {
  c: 46,
  d: 32,
  leftAlt: 56,
  leftBracket: 26,
  leftCtrl: 29,
  leftShift: 42,
  n: 49,
  q: 16,
  rightBracket: 27,
  t: 20,
  w: 17,
};

const displayNames: Readonly<Record<PhysicalKey, string>> = {
  c: "C",
  d: "D",
  leftAlt: "Alt",
  leftBracket: "[",
  leftCtrl: "Ctrl",
  leftShift: "Shift",
  n: "N",
  q: "Q",
  rightBracket: "]",
  t: "T",
  w: "W",
};

const evidenceNames: Readonly<Record<PhysicalKey, string>> = {
  c: "c",
  d: "d",
  leftAlt: "leftalt",
  leftBracket: "[",
  leftCtrl: "leftcontrol",
  leftShift: "leftshift",
  n: "n",
  q: "q",
  rightBracket: "]",
  t: "t",
  w: "w",
};

export interface KeydMonitor {
  readonly evidence: () => string;
  readonly stop: () => Promise<void>;
}

export interface PhysicalChord {
  readonly keys: readonly [PhysicalKey, ...PhysicalKey[]];
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
): Promise<void> {
  const label = chord.keys.map((key) => displayNames[key]).join("+");
  await step(`Inject physical ${label} before keyd`, async () => {
    const presses = chord.keys.map((key) => `${keyCodes[key]}:1`);
    const releases = [...chord.keys]
      .reverse()
      .map((key) => `${keyCodes[key]}:0`);
    await runCommand(["ydotool", "key", ...presses, ...releases], {
      env: { YDOTOOL_SOCKET: ydotoolSocket },
    });
  });
}

export async function waitForKeydChordEvidence(
  monitor: KeydMonitor,
  chord: PhysicalChord,
): Promise<string> {
  const label = chord.keys.map((key) => displayNames[key]).join("+");
  const expected = chord.keys.map((key) => `${evidenceNames[key]} down`);
  return waitFor(
    `keyd monitor to report the injected physical ${label} output`,
    async () => monitor.evidence(),
    (evidence) => expected.every((event) => evidence.includes(event)),
    { timeoutMs: 5_000 },
  );
}
