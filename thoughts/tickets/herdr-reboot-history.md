# Herdr Reboot History

Herdr restores workspace, tab, pane, layout, focus, and working-directory state
after a server or host restart, but Daniel observed that restored panes do not
retain their prior screen contents or useful interactive shell history.

## Evidence

Gauss currently runs Herdr 0.7.5. Its `~/.config/herdr/config.toml` contains
only `onboarding = false`; `experimental.pane_history` is unset and
`~/.config/herdr/session-history.json` does not exist.

The restored panes start new Bash processes. Current interactive Bash state has:

- `histappend` disabled;
- no per-prompt `history -a`/`history -n` synchronization;
- no explicit `HISTSIZE` or `HISTFILESIZE`;
- a shared `~/.bash_history` that concurrent panes can overwrite when shells
  exit.

Herdr's [session-state documentation](https://herdr.dev/docs/session-state/)
separates these concerns:

- snapshot restore recreates pane shape and working directories, not the old
  shell processes;
- opt-in pane screen history replays recent terminal contents after restart;
- pane screen history does not restore the old process or its in-memory readline
  history.

Herdr added pane screen history in 0.6.3, so the pinned 0.7.5 supports the
proposed experiment.

## Proposed Solution

Treat visible pane scrollback and interactive Bash history as two independent
layers.

1. Enable Herdr's opt-in screen replay:

   ```toml
   [experimental]
   pane_history = true
   ```

2. Configure interactive Bash declaratively on the managed hosts to:

   - enable `histappend`;
   - set explicit, generous `HISTSIZE` and `HISTFILESIZE` limits;
   - append new commands to `~/.bash_history` after each prompt;
   - import commands appended by other live panes without duplicating entries;
   - compose with any existing `PROMPT_COMMAND` instead of overwriting it.

3. Protect the Herdr state directory and `session-history.json` as sensitive
   terminal history. Pane output may contain secrets, tokens, prompts, and
   command output. Confirm restrictive ownership and modes before accepting the
   feature.

Do not implement this proposal until the behavior and confidentiality trade-off
are explicitly approved.

## Validation

Validate on Gauss first, then repeat the accepted behavior on Hardy:

1. Record existing Herdr configuration, Bash history settings, state-file
   permissions, and rollback copies.
2. In two ordinary shell panes with different working directories, alternate
   unique commands and print distinct visible-output markers.
3. Confirm a third live pane can see newly appended commands without either
   original pane exiting, and that history ordering/duplication is acceptable.
4. Detach and reattach without stopping the server; confirm live processes and
   terminal contents remain unchanged.
5. Restart the Herdr server, then confirm:
   - layout, focus, and working directories return;
   - recent visible screen contents replay;
   - new Bash shells can recall the unique commands from both old panes.
6. Reboot the host and repeat the same assertions.
7. Confirm `session-history.json` exists, contains the expected markers, and is
   inaccessible to other users. Inspect its retention/size behavior and accept
   the exposure risk before keeping it enabled.
8. Verify native agent-session restore separately: eligible agent panes resume
   through their integration and must not be mistaken for ordinary shell screen
   replay.
9. Confirm disabling pane history and reverting the Bash initialization returns
   to the prior behavior without damaging `session.json` or `~/.bash_history`.

Do not treat layout restoration alone as success. Acceptance requires both
recent visible pane contents and durable multi-pane Bash command history across
a real reboot.
