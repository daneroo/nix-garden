import { runCommand, step, waitFor } from "./desktop.ts";

export type PhysicalKey = "leftAlt" | "n";

const keyCodes: Readonly<Record<PhysicalKey, number>> = {
  leftAlt: 56,
  n: 49,
};

const displayNames: Readonly<Record<PhysicalKey, string>> = {
  leftAlt: "Alt",
  n: "N",
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
): Promise<string> {
  return waitFor(
    "keyd monitor to report the injected physical Alt+N output",
    async () => monitor.evidence(),
    (evidence) =>
      evidence.includes("leftalt down") && evidence.includes("n down"),
    { timeoutMs: 5_000 },
  );
}
