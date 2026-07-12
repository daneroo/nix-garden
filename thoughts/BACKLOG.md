# Backlog

Unscheduled work, grouped by theme. Keep entries brief; move growing detail to
`tickets/` as described in [docs/workflow.md](../docs/workflow.md).

## Now

- [ ] nix-formatting — choose and integrate the repository's Nix formatter and
      formatting check; high priority; ticket:
      [nix-formatting](tickets/nix-formatting.md)
- [ ] shared-repo-workflow — test and extract the reusable docs/thoughts
      workflow, then share the settled convention with Prosodio; ticket:
      [shared-repo-workflow](tickets/shared-repo-workflow.md)

## System

- [ ] Decide whether to add Home Manager later.
- [ ] If adding `thermald`, first revisit `docs/throttling.md`.
- [ ] Decide whether to track NixOS release branches or `nixos-unstable`.

## Repository Workflow

- [ ] concise-agent-docs — make agent-facing instructions in nix-hardy and
      Prosodio substantially shorter and easier to scan; ticket:
      [concise-agent-docs](tickets/concise-agent-docs.md)
- [ ] shared-workflow-skill — explore packaging the settled repository workflow
      as a personal, harness-neutral Agent Skill shared through Git; ticket:
      [shared-workflow-skill](tickets/shared-workflow-skill.md)
- [ ] repository-command-surface — rationalize, justify, and refine the roles of
      `Justfile`, `scripts/`, package-managed commands, and a possible Nix
      `devShell`; ticket:
      [repository-command-surface](tickets/repository-command-surface.md)

## Documentation

- [ ] hardy-hardware-notes — decide whether to keep or consolidate the inherited
      performance and throttling notes for `hardy`; ticket:
      [hardy-hardware-notes](tickets/hardy-hardware-notes.md)
