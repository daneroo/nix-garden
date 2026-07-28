"""Shared vocabulary for the harness's VM checks.

Prepended to the desktop test script so it contains only what is specific to
that suite. The driver runs Pyflakes and Mypy over the assembled script before
booting anything, so mistakes here are cheap.

Symbols the driver supplies and this file relies on: `machine`, `subtest`,
`retry`.

STATE BOUNDARY
  The suite's `subtest` blocks share one boot, session, and clipboard. State
  accumulates and order matters, and the driver offers no teardown hook -- its
  `nested()` context manager has no `except` or `finally`. Assert each
  precondition before acting so a test cannot pass by inheriting the state it
  means to create.

FIDELITY BOUNDARY
  These helpers inject at the guest's virtio keyboard, downstream of anything
  the host does to input. That is deliberate and permanent: a host running keyd
  swaps modifiers before QEMU ever sees them, so a chord typed by hand into a
  headed VM measures host keyd composed with guest keyd. Injection is the only
  channel that measures the guest's own configuration.
"""

import os


def as_daniel(cmd: str) -> str:
    """Run a command inside daniel's logged-in graphical session.

    `sudo -u daniel VAR=value cmd` does not work -- sudo treats the assignment
    as the command name -- so `env` is required. Getting this wrong cost a
    15-minute test run on 2026-07-25.
    """
    return (
        "sudo -u daniel env "
        "XDG_RUNTIME_DIR=/run/user/1000 "
        "WAYLAND_DISPLAY=wayland-0 "
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
        f"{cmd}"
    )


def guest_succeeds(cmd: str) -> str:
    """Run an assertion command without printing its implementation.

    The driver's `machine.succeed()` wraps every command in a terminal log
    block. That is useful while debugging a test but overwhelms the normal
    report, especially when a command is polled. Keep the command in an
    actionable failure while successful runs stay at the scenario level.
    """
    status, output = machine.execute(cmd)  # noqa: F821
    assert status == 0, f"guest command failed ({status}): {cmd}\n{output}"
    return output


def wait_for_guest(cmd: str, timeout_seconds: int = 30) -> None:
    """Wait quietly for a guest command to succeed."""
    retry(  # noqa: F821
        lambda _: machine.execute(cmd)[0] == 0,  # noqa: F821
        timeout_seconds=timeout_seconds,
    )


def wait_for_guest_output(
    cmd: str, expected: str, timeout_seconds: int = 30
) -> None:
    """Wait until a guest command succeeds with one exact stdout value."""
    retry(  # noqa: F821
        lambda _: machine.execute(cmd) == (0, expected),  # noqa: F821
        timeout_seconds=timeout_seconds,
    )


def wait_for_session() -> None:
    """Autologin, a compositor, and keyd owning the keyboard.

    The preconditions every keybinding assertion depends on. Cheap to call and
    safe to repeat.
    """
    machine.wait_for_unit("graphical.target")  # noqa: F821
    machine.wait_until_succeeds("pgrep -u daniel gnome-shell")  # noqa: F821
    machine.wait_for_file("/run/user/1000/wayland-0")  # noqa: F821
    machine.wait_for_unit("keyd.service")  # noqa: F821
    machine.succeed("journalctl -u keyd | grep -q 'QEMU Virtio Keyboard'")  # noqa: F821


def visible_pause(seconds: int, message: str) -> None:
    """Pause only when a human asked for the graphical demonstration."""
    if os.environ.get("NIX_GARDEN_TEST_SHOW") == "1":
        machine.log(message)  # noqa: F821
        machine.sleep(seconds)  # noqa: F821


def guided_pause(message: str) -> None:
    """Hold a guided case for the contracted four seconds in every mode."""
    machine.log(message)  # noqa: F821
    machine.sleep(4)  # noqa: F821


def send_chord(chord: str) -> None:
    """Inject one physical chord at the guest's keyboard.

    Chords are written in QEMU's key names, and its vocabulary is narrower than
    it looks: `alt` and `meta_l` are valid, `alt_l` and `meta` are not. The
    monitor answers `invalid parameter: alt_l`, but a caller that does not read
    the reply sees only silence -- which is exactly how the first run of this
    probe produced a confident false negative on 2026-07-25.

    Write the PHYSICAL key, not the logical one. Physical Alt, Ctrl, and Super
    remain distinct in the current model. QEMU's `meta_l` name injects the
    physical key that produces Linux Super; it does not describe Alt. Only the
    named Brave application map translates selected Alt chords after focus is
    known.
    """
    machine.send_key(chord)  # noqa: F821


def gnome_screensaver_active() -> bool:
    """Whether GNOME's screensaver is currently engaged."""
    out = guest_succeeds(
        as_daniel(
            "busctl --user --json=short call "
            "org.gnome.ScreenSaver /org/gnome/ScreenSaver "
            "org.gnome.ScreenSaver GetActive"
        )
    )
    return "true" in out


def wait_for_screensaver_service() -> None:
    """Block until the screensaver has claimed its bus name.

    Until it has, the chord has nothing to reach and a failure would say
    nothing about the binding.
    """
    wait_for_guest(as_daniel("busctl --user status org.gnome.ScreenSaver"))


def gnome_overview_property_command() -> str:
    """The public GNOME Shell property used as the desktop-ready boundary.

    This is intentionally a D-Bus property exported by `org.gnome.Shell`, not
    Shell JavaScript evaluated through `Eval`, a process-name guess, pixels, or
    a timing delay. GNOME owns the interface and emits changes when the overview
    opens or closes, so it describes the state the next injected key will
    actually encounter.

    This helper is GNOME-specific because the lock scenario is GNOME-specific.
    If gauss changes compositor, replace the scenario and this boundary with
    that compositor's documented semantic interface; do not preserve it with a
    compatibility shim or an arbitrary sleep.
    """
    return as_daniel(
        "busctl --user get-property "
        "org.gnome.Shell /org/gnome/Shell "
        "org.gnome.Shell OverviewActive"
    )


def wait_for_gnome_overview_interface() -> None:
    """Wait until GNOME has exported the property before reading its value."""
    wait_for_guest(gnome_overview_property_command())


def gnome_overview_active() -> bool:
    out = guest_succeeds(gnome_overview_property_command())
    return out.strip() == "b true"
