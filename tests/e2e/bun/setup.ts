import {
  getAtSpiAddress,
  runCommand,
  step,
  waitForExactOutput,
} from "./desktop.ts";

export interface Capabilities {
  readonly activeSessionId: string;
  readonly atSpiAddress: string;
  readonly desktopMode: "gnome" | "paperwm";
  readonly keydBinary: string;
  readonly ydotoolSocket: string;
}

const requiredExecutables = [
  "bash",
  "bun",
  "busctl",
  "dconf",
  "ghostty",
  "gnome-extensions",
  "gum",
  "id",
  "journalctl",
  "loginctl",
  "pgrep",
  "readlink",
  "sudo",
  "systemctl",
  "systemd-run",
  "wl-copy",
  "wl-paste",
  "ydotool",
] as const;

const ydotoolSocket = "/run/ydotoold/socket";

interface SessionProperties {
  readonly Active?: string;
  readonly Name?: string;
  readonly Remote?: string;
  readonly State?: string;
  readonly Type?: string;
}

function properties(stdout: string): SessionProperties {
  const result: Record<string, string> = {};
  for (const line of stdout.trim().split("\n")) {
    const separator = line.indexOf("=");
    if (separator > 0) {
      result[line.slice(0, separator)] = line.slice(separator + 1);
    }
  }
  return result;
}

async function activeGraphicalSession(): Promise<string> {
  const sessions = (
    await runCommand(["loginctl", "list-sessions", "--no-legend", "--no-pager"])
  ).stdout
    .trim()
    .split("\n")
    .map((line) => line.trim().split(/\s+/)[0])
    .filter(
      (session): session is string => session !== undefined && session !== "",
    );

  const matching: string[] = [];
  for (const session of sessions) {
    const observed = properties(
      (
        await runCommand([
          "loginctl",
          "show-session",
          session,
          "-p",
          "Name",
          "-p",
          "Active",
          "-p",
          "Remote",
          "-p",
          "Type",
          "-p",
          "State",
        ])
      ).stdout,
    );

    if (
      observed.Name === "daniel" &&
      observed.Active === "yes" &&
      observed.Remote === "no" &&
      observed.Type === "wayland" &&
      observed.State === "active"
    ) {
      matching.push(session);
    }
  }

  if (matching.length !== 1) {
    throw new Error(
      `expected one active local Wayland session for Daniel, got ${JSON.stringify(matching)}`,
    );
  }

  return matching[0]!;
}

async function requireExecutable(executable: string): Promise<void> {
  const result = await runCommand(
    [
      "bash",
      "-lc",
      'command -v -- "$1" >/dev/null',
      "nix-garden-e2e",
      executable,
    ],
    { check: false },
  );
  if (result.exitCode !== 0) {
    throw new Error(`required executable is unavailable: ${executable}`);
  }
}

export async function validateCapabilities(): Promise<Capabilities> {
  return step("Validate the live graphical-session capabilities", async () => {
    for (const executable of requiredExecutables) {
      await requireExecutable(executable);
    }

    await waitForExactOutput(["id", "-un"], "daniel\n");

    if (Bun.env.XDG_SESSION_TYPE !== "wayland") {
      throw new Error(
        `XDG_SESSION_TYPE must be "wayland", got ${JSON.stringify(Bun.env.XDG_SESSION_TYPE)}`,
      );
    }

    const runtimeDirectory = Bun.env.XDG_RUNTIME_DIR;
    const waylandDisplay = Bun.env.WAYLAND_DISPLAY;
    const dbusAddress = Bun.env.DBUS_SESSION_BUS_ADDRESS;
    if (
      runtimeDirectory === undefined ||
      waylandDisplay === undefined ||
      dbusAddress === undefined
    ) {
      throw new Error(
        "XDG_RUNTIME_DIR, WAYLAND_DISPLAY, and DBUS_SESSION_BUS_ADDRESS must come from the active graphical session",
      );
    }

    await runCommand([
      "bash",
      "-lc",
      'test -S "$1"',
      "nix-garden-e2e",
      `${runtimeDirectory}/${waylandDisplay}`,
    ]);
    await runCommand(["busctl", "--user", "status", "org.gnome.Shell"]);
    await waitForExactOutput(
      ["systemctl", "is-active", "keyd.service"],
      "active\n",
    );
    await waitForExactOutput(
      ["systemctl", "is-active", "ydotoold.service"],
      "active\n",
    );
    await runCommand(["sudo", "-n", "true"]);
    await runCommand(["ydotool", "debug"], {
      env: { YDOTOOL_SOCKET: ydotoolSocket },
    });

    const keydPid = (
      await runCommand(["pgrep", "--exact", "--oldest", "keyd"])
    ).stdout.trim();
    if (!/^[0-9]+$/.test(keydPid)) {
      throw new Error(`could not resolve the running keyd PID: ${keydPid}`);
    }
    const keydBinary = (
      await runCommand(["sudo", "-n", "readlink", "-f", `/proc/${keydPid}/exe`])
    ).stdout.trim();
    if (keydBinary === "") {
      throw new Error("could not resolve the running keyd executable");
    }
    const keydJournal = (
      await runCommand(["journalctl", "-u", "keyd.service", "-b", "--no-pager"])
    ).stdout;
    if (
      !keydJournal
        .split("\n")
        .some(
          (line) =>
            line.includes("DEVICE: match") &&
            line.includes("ydotoold virtual device"),
        )
    ) {
      throw new Error(
        "keyd has not reported matching the ydotoold virtual device; physical injection fidelity is unproven",
      );
    }

    const enabledExtensions = (
      await runCommand(["gnome-extensions", "list", "--enabled"])
    ).stdout
      .trim()
      .split("\n");
    const desktopMode = enabledExtensions.includes("paperwm@paperwm.github.com")
      ? "paperwm"
      : "gnome";

    const activeSessionId = await activeGraphicalSession();
    const atSpiAddress = await getAtSpiAddress();
    await runCommand([
      "busctl",
      `--address=${atSpiAddress}`,
      "--json=short",
      "call",
      "org.a11y.atspi.Registry",
      "/org/a11y/atspi/accessible/root",
      "org.a11y.atspi.Accessible",
      "GetChildren",
    ]);

    console.log(
      `  • session ${activeSessionId}; ${desktopMode}; AT-SPI ${atSpiAddress}`,
    );

    return {
      activeSessionId,
      atSpiAddress,
      desktopMode,
      keydBinary,
      ydotoolSocket,
    };
  });
}
