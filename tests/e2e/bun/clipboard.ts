import { runCommand, waitFor } from "./desktop.ts";

export type ClipboardBaseline =
  | {
      readonly kind: "empty";
      readonly types: readonly string[];
    }
  | {
      readonly kind: "text";
      readonly text: string;
      readonly types: readonly string[];
    };

const plainTextTypes = [
  "text/plain;charset=utf-8",
  "text/plain",
  "UTF8_STRING",
  "STRING",
  "TEXT",
] as const;

export async function captureClipboard(): Promise<ClipboardBaseline> {
  const types = (await runCommand(["wl-paste", "--list-types"])).stdout
    .trim()
    .split("\n")
    .filter((type) => type !== "");

  if (types.length === 1 && types[0] === "application/x-zerosize") {
    return { kind: "empty", types };
  }

  const plainTextType = plainTextTypes.find((type) => types.includes(type));
  if (plainTextType === undefined) {
    throw new Error(
      `refusing to replace a clipboard with no restorable plain-text representation: ${JSON.stringify(types)}`,
    );
  }
  if (
    types.some(
      (type) =>
        !plainTextTypes.includes(type as (typeof plainTextTypes)[number]),
    ) &&
    Bun.env.NIX_GARDEN_E2E_OVERWRITE_CLIPBOARD !== "1"
  ) {
    throw new Error(
      `refusing to discard rich clipboard types outside the guarded entry point: ${JSON.stringify(types)}`,
    );
  }

  const text = (
    await runCommand(["wl-paste", "--type", plainTextType, "--no-newline"])
  ).stdout;
  return { kind: "text", text, types };
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

export async function restoreClipboard(
  baseline: ClipboardBaseline,
): Promise<void> {
  if (baseline.kind === "text") {
    await writeClipboard(baseline.text);
    return;
  }

  await runCommand(["wl-copy", "--clear"]);
  await waitFor(
    "clipboard to return to its empty baseline",
    async () =>
      (await runCommand(["wl-paste", "--list-types"])).stdout
        .trim()
        .split("\n")
        .filter((type) => type !== ""),
    (types) => types.length === 1 && types[0] === "application/x-zerosize",
  );
}
