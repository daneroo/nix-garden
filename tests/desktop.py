"""Desktop configuration and behavior, exercised in one disposable VM."""

# Keep driver actions and failures visible without flooding the invoking
# terminal with the guest's kernel and service logs.
serial_stdout_off()

wait_for_session()
wait_for_gnome_overview_interface()

# gnome-settings-daemon publishes the exact readiness boundary for media-key
# bindings such as lock: org.gnome.SettingsDaemon.MediaKeys.target, whose own
# unit description is "GNOME keyboard shortcuts target". This is deliberately
# GNOME-specific; a future compositor gets its own small adapter rather than a
# compatibility shim or a timing delay.
wait_for_guest(
    as_daniel(
        "systemctl --user is-active org.gnome.SettingsDaemon.MediaKeys.target"
    )
)


def wait_for_ghostty_frames(*titles: str) -> None:
    """Wait for the complete set of fixture-owned Ghostty window titles."""
    wait_for_guest(
        as_daniel("ghostty-frame-probe " + " ".join(titles)),
        timeout_seconds=30,
    )


with subtest("declared dotfiles resolve into the store"):
    for path in [
        "/home/daniel/.config/ghostty/config",
        "/home/daniel/.config/keyd/app.conf",
        "/home/daniel/.local/share/gnome-shell/extensions/"
        "keyd@keyd.rvaiya.github.com",
    ]:
        guest_succeeds(f"test -e {path}")
        guest_succeeds(f"readlink -f {path} | grep -q '^/nix/store/'")

with subtest("the patched GNOME Shell extension is loaded"):
    wait_for_guest(as_daniel("gnome-extensions info keyd@keyd.rvaiya.github.com"))

with subtest("keyd-application-mapper is running"):
    wait_for_guest("pgrep -f keyd-application-mapper")

with subtest("production Ghostty bindings and GNOME exclusions are loaded"):
    bindings = guest_succeeds(as_daniel("ghostty +list-keybinds --plain"))
    for binding in [
        "keybind = super+c=copy_to_clipboard:mixed",
        "keybind = super+v=paste_from_clipboard",
        "keybind = super+t=new_tab",
        "keybind = super+w=close_tab:this",
        "keybind = super+n=new_window",
    ]:
        assert binding in bindings.splitlines(), (
            f"production Ghostty config omitted {binding!r}"
        )

    notification = guest_succeeds(
        as_daniel(
            "gsettings get org.gnome.shell.keybindings "
            "focus-active-notification"
        )
    ).strip()
    assert notification == "@as []", (
        f"GNOME still owns Super+N: {notification}"
    )

    message_tray = guest_succeeds(
        as_daniel(
            "gsettings get org.gnome.shell.keybindings toggle-message-tray"
        )
    ).strip()
    assert message_tray == "['<Super>m']", (
        f"GNOME still owns Super+V: {message_tray}"
    )

guest_succeeds(
    as_daniel(
        "systemd-run --user --collect "
        "--setenv=WAYLAND_DISPLAY=wayland-0 "
        "--setenv=XDG_RUNTIME_DIR=/run/user/1000 "
        "--setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
        "--unit=nix-garden-ghostty-test "
        "ghostty --config-file=/etc/nix-garden/ghostty-test-config"
    )
)
wait_for_ghostty_frames("nix-garden-test-surface-1")

# A fresh GNOME login starts in Activities. Closing it only after Ghostty has a
# real window gives the compositor a deterministic surface to focus. Typing a
# protocol command and observing the resulting title transition proves that
# focus before any application chord is injected.
if gnome_overview_active():
    visible_pause(4, "Ghostty is ready; closing Activities in four seconds")
    send_chord("esc")
    retry(lambda _: not gnome_overview_active(), timeout_seconds=10)

with subtest("Ghostty owns keyboard focus"):
    machine.send_chars("FOCUS\n")
    wait_for_ghostty_frames("nix-garden-test-surface-1-focused")

with subtest("Alt+C copies selected Ghostty content"):
    visible_pause(4, "selecting COPY_PROBE, then injecting Alt+C")
    send_chord("ctrl-shift-a")
    send_chord("alt-c")
    wait_for_guest_output(
        as_daniel("wl-paste --no-newline"),
        "COPY_PROBE",
        timeout_seconds=10,
    )

with subtest("Alt+T creates and selects a Ghostty tab"):
    visible_pause(4, "injecting Alt+T; watch the tab bar")
    send_chord("alt-t")
    wait_for_ghostty_frames("nix-garden-test-surface-2")
    machine.send_chars("FOCUS\n")
    wait_for_ghostty_frames("nix-garden-test-surface-2-focused")

with subtest("Alt+W closes the selected Ghostty tab"):
    visible_pause(4, "injecting Alt+W; the selected tab will close")
    send_chord("alt-w")
    wait_for_ghostty_frames("nix-garden-test-surface-1-focused")

with subtest("Alt+N creates and focuses a Ghostty window"):
    visible_pause(4, "injecting Alt+N; a second Ghostty window will appear")
    send_chord("alt-n")
    wait_for_ghostty_frames(
        "nix-garden-test-surface-1-focused",
        "nix-garden-test-surface-3",
    )
    machine.send_chars("WINDOW_FOCUS\n")
    wait_for_ghostty_frames(
        "nix-garden-test-surface-1-focused",
        "nix-garden-test-surface-3-window-focused",
    )

with subtest("Alt+V pastes clipboard bytes into Ghostty"):
    guest_succeeds(
        "printf 'PASTE_PROBE\\n' | " + as_daniel("wl-copy")
    )
    clipboard = guest_succeeds(
        as_daniel("wl-paste --no-newline")
    )
    assert clipboard == "PASTE_PROBE\n", (
        f"fixture clipboard changed before paste: {clipboard!r}"
    )
    visible_pause(4, "injecting Alt+V; the focused window will acknowledge it")
    send_chord("alt-v")
    wait_for_ghostty_frames(
        "nix-garden-test-surface-1-focused",
        "nix-garden-test-paste-surface-3-PASTE_PROBE",
    )

with subtest("the visible session starts unlocked"):
    wait_for_screensaver_service()
    assert not gnome_screensaver_active(), (
        "session was already locked; the chord test would prove nothing"
    )
    lock_binding = guest_succeeds(
        as_daniel(
            "dconf read "
            "/org/gnome/settings-daemon/plugins/media-keys/screensaver"
        )
    ).strip()
    assert lock_binding == "['<Super><Shift>l']", (
        f"GNOME loaded the wrong lock binding: {lock_binding}"
    )

with subtest("Alt+Shift+L locks and the VM password unlocks the session"):
    visible_pause(4, "injecting Alt+Shift+L; the session will lock")
    send_chord("alt-shift-l")
    retry(lambda _: gnome_screensaver_active(), timeout_seconds=30)
    visible_pause(5, "lock confirmed; unlocking with the VM fixture password")

    # This plaintext is intentionally public and must match `password` in
    # modules/vm-layer.nix. It exists only in VM configurations.
    # Typing into the lock curtain both reveals the password prompt and enters
    # the credential; this is the same input path a person uses, not a D-Bus
    # request that bypasses authentication. Nixpkgs' own graphical desktop
    # tests use send_chars(..., delay=0.2) for this exact kind of assertion.
    machine.send_chars("secret\n", delay=0.2)
    retry(lambda _: not gnome_screensaver_active(), timeout_seconds=30)
    visible_pause(4, "unlock confirmed")
