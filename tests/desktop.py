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

# A fresh GNOME login starts in Activities. Close it before opening any probe
# window so focus is an explicit precondition of modifier observation.
if gnome_overview_active():
    send_chord("esc")
    retry(lambda _: not gnome_overview_active(), timeout_seconds=10)


def wait_for_ghostty_frames(*titles: str) -> None:
    """Wait for the complete set of fixture-owned Ghostty window titles."""
    wait_for_guest(
        as_daniel("ghostty-frame-probe " + " ".join(titles)),
        timeout_seconds=30,
    )


def wait_for_brave_frames(count: int, title: str | None = None) -> None:
    """Wait for Brave's top-level frame count and optional active-tab title."""
    command = f"brave-frame-probe {count}"
    if title is not None:
        command += f" '{title}'"
    wait_for_guest(as_daniel(command), timeout_seconds=30)


def brave_page_count_command() -> str:
    return (
        "curl --fail --silent http://127.0.0.1:9222/json/list "
        "| jq '[.[] | select(.type == \"page\")] | length'"
    )


def wait_for_brave_pages(count: int) -> None:
    wait_for_guest(
        as_daniel(
            f"test \"$({brave_page_count_command()})\" = {count}"
        ),
        timeout_seconds=30,
    )


def custom_binding(index: int) -> str:
    return guest_succeeds(
        as_daniel(
            "dconf read /org/gnome/settings-daemon/plugins/media-keys/"
            f"custom-keybindings/custom{index}/binding"
        )
    ).strip()


def probe_modifier(physical_chord: str, expected: str) -> None:
    """Inject a physical modifier plus X and assert GTK's exact logical mask."""
    result = f"/run/user/1000/nix-garden-modifier-{expected.lower()}"
    guest_succeeds(f"rm -f {result}")
    guest_succeeds(
        as_daniel(
            "systemd-run --user --collect "
            f"--unit=nix-garden-modifier-{expected.lower()} "
            f"modifier-probe {result}"
        )
    )
    wait_for_guest(f"test -e {result}")
    if guest_succeeds(f"cat {result}") != "FOCUSED":
        send_chord("alt-tab")
        wait_for_guest_output(f"cat {result}", "FOCUSED")
    send_chord(physical_chord)
    wait_for_guest(f'test "$(cat {result})" != FOCUSED')
    actual = guest_succeeds(f"cat {result}")
    assert actual == expected, (
        f"physical {physical_chord} produced {actual!r}, expected {expected!r}"
    )


with subtest("physical Alt, Ctrl, and Super have distinct logical modifiers"):
    probe_modifier("alt-x", "ALT")
    probe_modifier("ctrl-x", "CTRL")
    probe_modifier("meta_l-x", "SUPER+MOD4")

with subtest("declared keyd configuration has no Alt-to-Super carrier"):
    guest_succeeds(
        "! grep -R -E "
        "'^(leftalt|rightalt)[[:space:]]*=[[:space:]]*layer\\(meta\\)' "
        "/etc/keyd"
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

with subtest("production Ghostty and GNOME bindings are loaded"):
    bindings = guest_succeeds(as_daniel("ghostty +list-keybinds --plain"))
    for binding in [
        "keybind = alt+c=copy_to_clipboard:mixed",
        "keybind = alt+v=paste_from_clipboard",
        "keybind = alt+t=new_tab",
        "keybind = alt+w=close_tab:this",
        "keybind = alt+shift+]=next_tab",
        "keybind = alt+shift+[=previous_tab",
        "keybind = alt+k=clear_screen",
        "keybind = alt+n=new_window",
        "keybind = alt+q=quit",
    ]:
        assert binding in bindings.splitlines(), (
            f"production Ghostty config omitted {binding!r}"
        )

    # Disabled 2026-07-30, kept commented so the assertions stay legible beside
    # the reason they stopped holding. Both asserted GNOME's own upstream
    # defaults rather than anything this repository declares, so any extension
    # or GNOME bump invalidates them. PaperWM -- in enabled-extensions on both
    # hosts since 2026-07-28 (d913fc7) -- blanks every conflicting key from its
    # enable() path: new-window claims Super+N, and center-vertically claims
    # Super+V, which costs Super+M too because overrideConflicts() blanks the
    # whole gsettings key rather than the one colliding accelerator.
    #
    # The retired Alt-to-Super carrier these originally guarded is asserted
    # directly by the modifier probe and the /etc/keyd grep above, so nothing
    # is left uncovered. Do not restore them after toggling PaperWM off:
    # restoreConflicts() makes them pass again without making them any less
    # brittle. See docs/e2e-testing.md.
    #
    # notification = guest_succeeds(
    #     as_daniel(
    #         "gsettings get org.gnome.shell.keybindings "
    #         "focus-active-notification"
    #     )
    # ).strip()
    # assert notification == "['<Super>n']", (
    #     f"GNOME did not restore its stock Super+N binding: {notification}"
    # )
    #
    # message_tray = guest_succeeds(
    #     as_daniel(
    #         "gsettings get org.gnome.shell.keybindings toggle-message-tray"
    #     )
    # ).strip()
    # assert message_tray == "['<Super>v', '<Super>m']", (
    #     f"GNOME did not restore its stock message-tray bindings: {message_tray}"
    # )

    window_menu = guest_succeeds(
        as_daniel(
            "gsettings get org.gnome.desktop.wm.keybindings "
            "activate-window-menu"
        )
    ).strip()
    assert window_menu == "@as []", (
        f"GNOME still owns native Alt+Space: {window_menu}"
    )

    for index, binding in enumerate(
        [
            "<Alt>space",
            "<Alt><Shift>space",
            "<Alt><Shift>q",
        ]
    ):
        assert custom_binding(index) == repr(binding), (
            f"GNOME custom{index} omitted direct binding {binding}"
        )

    # Disabled 2026-07-30 for the reason recorded above: PaperWM's live-alt-tab
    # claims both of switch-applications' stock accelerators, Super+Tab and
    # Alt+Tab, so the key is blanked whenever the extension is enabled.
    #
    # switch_apps = guest_succeeds(
    #     as_daniel(
    #         "gsettings get org.gnome.desktop.wm.keybindings "
    #         "switch-applications"
    #     )
    # ).strip()
    # assert switch_apps == "['<Super>Tab', '<Alt>Tab']", (
    #     f"GNOME did not retain native Alt+Tab and Super+Tab: {switch_apps}"
    # )

    input_source = guest_succeeds(
        as_daniel(
            "gsettings get org.gnome.desktop.wm.keybindings "
            "switch-input-source"
        )
    ).strip()
    assert input_source == "['<Super>space', 'XF86Keyboard']", (
        f"GNOME did not restore its stock input-source bindings: {input_source}"
    )

    screenshots = guest_succeeds(
        as_daniel(
            "gsettings get org.gnome.shell.keybindings screenshot"
        )
    ).strip()
    assert screenshots == "['<Shift>Print', '<Alt><Shift>3']", (
        f"GNOME loaded the wrong full-screen bindings: {screenshots}"
    )

    screenshot_ui = guest_succeeds(
        as_daniel(
            "gsettings get org.gnome.shell.keybindings show-screenshot-ui"
        )
    ).strip()
    assert screenshot_ui == "['Print', '<Alt><Shift>4']", (
        f"GNOME loaded the wrong screenshot UI bindings: {screenshot_ui}"
    )

with subtest("Brave's complete focused Alt translation is declared"):
    mapper = guest_succeeds(
        "cat /home/daniel/.config/keyd/app.conf"
    ).splitlines()
    for binding in [
        "alt.c = C-c",
        "alt.v = C-v",
        "alt.t = C-t",
        "alt.w = C-w",
        "alt+shift.t = C-S-t",
        "alt.n = C-n",
        "alt.l = C-l",
        "alt.f = C-f",
        "alt+shift.rightbrace = C-tab",
        "alt+shift.leftbrace = C-S-tab",
        "alt+shift.l = A-S-l",
    ]:
        assert binding in mapper, f"Brave mapper omitted {binding!r}"
    for forbidden in ["meta.", "alt+shift.w", "alt.q"]:
        assert not any(forbidden in line for line in mapper), (
            f"Brave mapper retained out-of-scope binding {forbidden!r}"
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
    assert lock_binding == (
        "['<Alt><Shift>l', '<Super>l', '<Control><Alt>q']"
    ), (
        f"GNOME loaded the wrong lock binding: {lock_binding}"
    )

with subtest("Alt+Shift+L lock is injected and guided for four seconds"):
    guest_succeeds(
        "keyd_bin=$(readlink -f /proc/$(pgrep -xo keyd)/exe); "
        "timeout 8 \"$keyd_bin\" monitor -t "
        ">/tmp/nix-garden-keyd-monitor 2>&1 &"
    )
    machine.sleep(1)
    send_chord("alt-shift-l")
    guided_pause(
        "Alt+Shift+L injected; observe the lock screen before automatic unlock"
    )
    evidence = guest_succeeds("cat /tmp/nix-garden-keyd-monitor")
    for event in ["leftalt down", "leftshift down", "l down"]:
        assert event in evidence, (
            f"Alt+Shift+L omitted {event!r}:\n{evidence}"
        )

    # This plaintext is intentionally public and must match `password` in
    # modules/vm-layer.nix. It exists only in VM configurations.
    # Send the same cleanup in both modes. In visible mode it unlocks after the
    # guided lock observation; headless GNOME ignores the accelerator, so Escape
    # dismisses any text surface opened by the harmless credential keystrokes.
    machine.send_chars("secret\n", delay=0.2)
    retry(lambda _: not gnome_screensaver_active(), timeout_seconds=30)
    send_chord("esc")

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

with subtest("Alt+Shift+[ and Alt+Shift+] navigate Ghostty tabs"):
    send_chord("alt-shift-bracket_left")
    machine.send_chars("FOCUS\n")
    wait_for_ghostty_frames("nix-garden-test-surface-1-focused")
    send_chord("alt-shift-bracket_right")
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

with subtest("Ctrl+C reaches the Ghostty PTY as Control-C"):
    send_chord("ctrl-c")
    send_chord("ret")
    wait_for_ghostty_frames(
        "nix-garden-test-surface-1-focused",
        "nix-garden-test-control-c-surface-3",
    )

with subtest("unbound Alt+D reaches the Ghostty PTY as an Alt sequence"):
    send_chord("alt-d")
    send_chord("ret")
    wait_for_ghostty_frames(
        "nix-garden-test-surface-1-focused",
        "nix-garden-test-alt-d-surface-3",
    )

with subtest("Alt+K clear-screen action is guided for four seconds"):
    machine.send_chars("POPULATE\n")
    wait_for_ghostty_frames(
        "nix-garden-test-surface-1-focused",
        "nix-garden-test-populated-surface-3",
    )
    send_chord("alt-k")
    guided_pause(
        "Alt+K injected after populating Ghostty; observe the clear-screen result"
    )

guest_succeeds(
    as_daniel(
        "systemd-run --user --collect "
        "--unit=nix-garden-brave-fixture "
        "darkhttpd /etc/nix-garden/brave-fixture "
        "--addr 127.0.0.1 --port 18080"
    )
)
wait_for_guest(
    "curl --fail --silent http://127.0.0.1:18080/one.html >/dev/null"
)
guest_succeeds(
    as_daniel(
        "systemd-run --user --collect "
        "--setenv=WAYLAND_DISPLAY=wayland-0 "
        "--setenv=XDG_RUNTIME_DIR=/run/user/1000 "
        "--setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
        "--unit=nix-garden-brave-test "
        "brave "
        "--user-data-dir=/run/user/1000/nix-garden-brave-profile "
        "--remote-debugging-port=9222 "
        "--remote-allow-origins=* "
        "--force-renderer-accessibility "
        "--no-first-run "
        "--no-default-browser-check "
        "--password-store=basic "
        "http://127.0.0.1:18080/one.html"
    )
)
wait_for_brave_pages(1)
wait_for_brave_frames(1, "Nix Garden Brave One")

with subtest("Alt+C copies selected Brave fixture content"):
    guest_succeeds("printf BEFORE | " + as_daniel("wl-copy"))
    wait_for_guest_output(as_daniel("wl-paste --no-newline"), "BEFORE")
    send_chord("alt-c")
    wait_for_guest_output(
        as_daniel("wl-paste --no-newline"),
        "COPY_PROBE",
        timeout_seconds=10,
    )

with subtest("Alt+V pastes into Brave while native Ctrl remains native"):
    guest_succeeds("printf PASTE_PROBE | " + as_daniel("wl-copy"))
    wait_for_guest_output(
        as_daniel("wl-paste --no-newline"),
        "PASTE_PROBE",
        timeout_seconds=10,
    )
    send_chord("alt-v")
    wait_for_brave_frames(1, "Nix Garden Brave One PASTE_PROBE")
    send_chord("ctrl-a")
    send_chord("ctrl-c")
    wait_for_guest_output(
        as_daniel("wl-paste --no-newline"),
        "PASTE_PROBE",
        timeout_seconds=10,
    )

with subtest("Alt+T creates a Brave tab and Alt+L focuses its address"):
    send_chord("alt-t")
    wait_for_brave_pages(2)
    send_chord("alt-l")
    machine.send_chars("http://127.0.0.1:18080/two.html\n")
    wait_for_brave_frames(1, "Nix Garden Brave Two")

with subtest("Alt+F find is guided for four seconds"):
    send_chord("alt-f")
    machine.send_chars("FIND_NEEDLE")
    guided_pause(
        "Alt+F injected in Brave; observe FIND_NEEDLE in the find surface"
    )
    send_chord("esc")
    wait_for_brave_frames(1, "Nix Garden Brave Two")

with subtest("Alt+Shift+[ and Alt+Shift+] navigate Brave tabs"):
    send_chord("alt-shift-bracket_left")
    wait_for_brave_frames(1, "Nix Garden Brave One")
    send_chord("alt-shift-bracket_right")
    wait_for_brave_frames(1, "Nix Garden Brave Two")

with subtest("Alt+W closes and Alt+Shift+T reopens a Brave tab"):
    send_chord("alt-w")
    wait_for_brave_pages(1)
    wait_for_brave_frames(1, "Nix Garden Brave One")
    send_chord("alt-shift-t")
    wait_for_brave_pages(2)
    wait_for_brave_frames(1, "Nix Garden Brave Two")

with subtest("Alt+N creates a Brave window and Alt+W closes it"):
    send_chord("alt-n")
    wait_for_brave_pages(3)
    wait_for_brave_frames(2)
    send_chord("alt-w")
    wait_for_brave_pages(2)
    wait_for_brave_frames(1, "Nix Garden Brave Two")

with subtest("Alt+Shift+Q logout dialog is guided and Escape preserves the session"):
    assert not gnome_screensaver_active(), (
        "session was locked before the logout-dialog action"
    )
    guest_succeeds("pgrep -u daniel gnome-shell")
    send_chord("alt-shift-q")
    # GNOME exposes no stable public property for this Shell-owned modal.
    # Exercise the complete action/cancel path without scraping Shell internals.
    guided_pause(
        "Alt+Shift+Q injected; observe GNOME's logout confirmation dialog"
    )
    send_chord("esc")
    guest_succeeds("pgrep -u daniel gnome-shell")
    assert not gnome_screensaver_active(), (
        "logout cancellation did not preserve the unlocked session"
    )
