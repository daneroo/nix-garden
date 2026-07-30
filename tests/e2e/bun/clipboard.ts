import { runCommand, waitFor } from "./desktop.ts";

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

  await waitForClipboardText(text);
}

export async function waitForClipboardText(text: string): Promise<void> {
  await waitFor(
    "clipboard text to match the requested value",
    async () => {
      const result = await runCommand(["wl-paste", "--no-newline"], {
        check: false,
        timeoutMs: 2_000,
      });
      return {
        exitCode: result.exitCode,
        matches: result.stdout === text,
        timedOut: result.timedOut,
      };
    },
    (observed) =>
      !observed.timedOut && observed.exitCode === 0 && observed.matches,
  );
}

// The suite warns up front that it overwrites the clipboard and does not restore
// it. Clearing at the end leaves an empty clipboard rather than a probe value;
// `wl-copy --clear` clears the selection and exits without leaving a persistent
// owner, so it avoids the wl-copy-owner state that wedges Mutter's clipboard.
export async function clearClipboard(): Promise<void> {
  await runCommand(["wl-copy", "--clear"]);
}
