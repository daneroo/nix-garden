# shared-workflow-skill — Explore a Shared Agent Skill

After the repository workflow has been exercised and refined in nix-garden and
Prosodio, evaluate packaging its reusable procedure as a personal,
harness-neutral Agent Skill.

## Objective

Make it easy for different agent harnesses and repositories to adopt, audit, and
update the shared docs/thoughts workflow without hiding repository policy or
blindly overwriting local commands and safety constraints.

## Questions

- Which content belongs in the portable `SKILL.md`, shared references, and
  optional synchronization scripts?
- Should the canonical common template live in a dedicated personal Git
  repository?
- Can `npx skills` install and update the skill reliably for Codex and the other
  harnesses in use?
- How should repositories detect upstream changes while retaining deliberate
  local adaptations?
- Which Agent Skills features are genuinely portable, and which harness-specific
  extensions should be avoided or isolated?
- How should releases, update checks, and rollback work for a personally owned
  skill?
- What security review is appropriate before installing skill instructions or
  scripts?

## Preconditions

- The workflow has seen normal backlog, ticket, design, plan, archive, and
  harvest cycles.
- The common core and repository-specific policy are clearly separated.
- Trivial settled conventions have been back-ported to Prosodio.
- The command-surface decision explains how a skill invokes or verifies local
  quality gates without assuming one package manager.

## Pilot

- Create the smallest useful skill in a personal Git repository.
- Install it project-locally in nix-garden and Prosodio.
- Exercise it with Codex and at least one other harness.
- Test adoption, drift detection, update, and rollback.
- Keep each repository's checked-in workflow readable and authoritative without
  the skill installed.
