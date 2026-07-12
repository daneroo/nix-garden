# shared-repo-workflow — Share the Repository Workflow

Objective: test this repository's docs/thoughts workflow in real use, extract
the stable common core, and reuse it in Prosodio without erasing either repo's
local commands or constraints.

## Current Decisions

- Durable reference belongs in `docs/`; transient work belongs in `thoughts/`,
  except for the persistent `thoughts/BACKLOG.md` index.
- Document and thought filenames use lowercase kebab-case. Uppercase is reserved
  for notable indexes or control files such as `README.md` and `BACKLOG.md`.
- The shared workflow may require invariants while allowing local mechanisms.
  The required quality gate is `just pre-commit` here and `bun run ci` in
  Prosodio.
- Prettier owns Markdown formatting and `markdownlint-cli2`, configured with
  `markdownlint/style/prettier`, owns structural linting in both repos. Local
  command surfaces may differ while preserving that split. Both current repos
  use `bunx`; nix-garden installs Bun itself through Nixpkgs.
- Repo-local workflow documentation remains understandable and authoritative
  without an installed skill.

## Candidate Distribution

Agent Skill exploration is tracked separately in
[shared-workflow-skill](shared-workflow-skill.md). This ticket first establishes
what is actually shared and proves the convention in both repositories.

## Next Work

- Back-port the lowercase filename convention and other trivial settled changes
  to Prosodio promptly.
- Compare both workflows after each has seen normal plan/ticket/archive usage.
- Separate truly shared text from examples, commands, and safety rules owned by
  one repository.
- Decide whether synchronization is manual, a template update/check script, or
  both.
