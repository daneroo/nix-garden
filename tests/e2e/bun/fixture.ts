export {};

const titlePrefix = Bun.env.NIX_GARDEN_E2E_TITLE_PREFIX;
if (titlePrefix === undefined || titlePrefix === "") {
  throw new Error("NIX_GARDEN_E2E_TITLE_PREFIX is unavailable");
}

const surfaceTitle = `${titlePrefix}-surface-${process.pid}`;

function setTitle(title: string): void {
  process.stdout.write(`\u001B]0;${title}\u0007`);
}

setTitle(surfaceTitle);
process.stdin.setRawMode(true);
process.stdin.resume();

let pendingEscape = false;
process.stdin.on("data", (chunk: Buffer) => {
  for (const byte of chunk) {
    if (pendingEscape) {
      pendingEscape = false;
      if (byte === "d".charCodeAt(0)) {
        setTitle(`${surfaceTitle}-alt-d`);
        continue;
      }
    }

    if (byte === 0x1b) {
      pendingEscape = true;
    } else if (byte === 0x03) {
      setTitle(`${surfaceTitle}-control-c`);
    }
  }
});
