import { runCommand, waitForExactOutput } from "./desktop.ts";

export interface ClipboardBaseline {
  readonly text: string;
  readonly types: readonly string[];
}

const supportedTypes = new Set(["text/plain", "text/plain;charset=utf-8"]);

export async function captureClipboard(): Promise<ClipboardBaseline> {
  const types = (await runCommand(["wl-paste", "--list-types"])).stdout
    .trim()
    .split("\n")
    .filter((type) => type !== "");

  if (types.length === 0 || types.some((type) => !supportedTypes.has(type))) {
    throw new Error(
      `refusing to replace a clipboard that cannot be restored as plain text: ${JSON.stringify(types)}`,
    );
  }

  const text = (await runCommand(["wl-paste", "--no-newline"])).stdout;
  return { text, types };
}

export async function writeClipboard(text: string): Promise<void> {
  const process = Bun.spawn({
    cmd: ["wl-copy"],
    stdin: new Blob([text]),
    stdout: "ignore",
    stderr: "ignore",
  });
  const exitCode = await process.exited;
  if (exitCode !== 0) {
    throw new Error(`wl-copy exited ${exitCode}`);
  }

  await waitForExactOutput(["wl-paste", "--no-newline"], text);
}

export async function restoreClipboard(
  baseline: ClipboardBaseline,
): Promise<void> {
  await writeClipboard(baseline.text);
}
