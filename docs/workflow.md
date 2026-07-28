# Workflow

```text
state         backlogged -> planned -> active -> done -> closed
backlog item  [-----------------------------------------------]
ticket        [optional working detail------------------------]
plan                       [planned -> active -> done] delete/archive
```

At closeout, harvest durable facts into `docs/` when useful, then remove
transient artifacts.

Files in `thoughts/` use lowercase kebab-case. Keep the backlog readable in one
pass; move detail into a ticket when an entry grows beyond a few lines. See
[markdown.md](markdown.md) for documentation filenames.

## Shared Convention

This workflow intentionally shares its core model with Prosodio: durable
reference in `docs/`; a persistent backlog plus transient tickets, designs,
plans, research, and reviews in `thoughts/`. The repos may adapt the details,
but changes to that common model should be considered for both repos.

For now, keep the convention synchronized by explicitly back-porting useful
changes rather than treating either repo's file as generated. If more repos
adopt it or drift becomes costly, promote the common text to a small shared
template with an update/check mechanism; keep repo-specific content local.

A harness-neutral Agent Skill may teach agents how to adopt, audit, or update
this convention across repositories. The skill should point to the shared
template and perform the synchronization workflow; it should not make installed
skill copies or harness-specific instruction files the canonical source.

Filename casing under `docs/` is a per-repository choice, not part of the shared
workflow core.

## Optional Coordinator Tasks

Codex may keep one persistent project task as a coordination convenience. That
task can retain working context across backlog refinement, sequencing,
cross-feature decisions, and handoffs to narrower feature tasks or subagents.
Naming it `<project> — coordinator` makes the role visible, but the name grants
no special authority.

The coordinator is tooling candy, not project state:

- The repository's backlog, tickets, designs, plans, documentation, commits, and
  checks remain authoritative and harness-neutral.
- The coordinator owns project-level boundaries and integration; a feature task
  may deepen its ticket, prepare its executable plan, implement, verify, and
  report the outcome.
- Handoffs must be understandable from the ticket or plan without access to the
  coordinator transcript. Another agent harness or a human can therefore
  participate at any point.
- Compacted or resumed task context is useful continuity, never a substitute for
  checking the repository and running the required quality gate.
- Do not let multiple tasks edit the same checkout concurrently. Work
  sequentially or use separate branches and worktrees with an explicit
  integration owner.

This pattern is optional and currently Codex-specific. The shared repository
workflow must remain complete when no persistent coordinator exists.

## Required Invariants

Each adopting repository names one required quality-gate command in its local
instructions. Plans and agents must run that gate after edits and before
commits; the implementation remains repository-specific. For nix-garden the gate
is `just check`. For Prosodio it is `bun run ci`.

The shared workflow defines the invariant, not a universal command. A copied or
generated workflow must preserve the adopting repository's local command and
must not overwrite repository-specific safety constraints.

## Canonical Managed-Host Checkout

On managed NixOS hosts, `/home/daniel/nix-garden` is the canonical operational
checkout. `programs.nh.flake` exports that path through `NH_FLAKE`, allowing
`nh os` commands to find the flake from any directory. Moving or removing the
checkout breaks unqualified `nh` commands; pass an explicit flake path or use
the documented raw NixOS recovery commands when the canonical checkout is
unavailable.

Installing `nh` does not replace repository policy. Until `nh-iteration`
deliberately rewires the lifecycle, `just plan` and `just apply` remain
authoritative for the Git-state check, quality gate, activation confirmation,
and post-switch verification.

## Backlog

`thoughts/BACKLOG.md` is the index of unscheduled work, grouped by theme. Use a
`## Now` section when ordering the next items would be useful.

```md
- [ ] <id> — <short outcome>; ticket: [<id>](tickets/<id>.md)
```

The stable `<id>` is a lowercase kebab-case slug shared by its ticket, design,
and plan. At closeout, move the item to a newest-first `## Closed` section with
its date, outcome, and archived-plan link when one remains useful.

## Tickets

`thoughts/tickets/<id>.md` holds working detail for one backlog item: evidence,
constraints, options, and pending decisions. It has no required schema beyond a
clear title. Delete it at closeout after its durable facts have a stable home;
Git retains its history.

## Designs

`thoughts/design/<id>.md` explains a problem, constraints, alternatives,
decisions, and open questions. The directory already identifies the artifact as
a design; do not repeat `-design` in its filename. A design says what should be
built and why; a plan turns the chosen direction into executable steps.

Consolidate superseded drafts rather than accumulating them. When the design is
settled, harvest durable facts and delete the transient design.

## Plans

Create `thoughts/plans/<id>.md` when work is scheduled:

```md
# <Title>

Status: planned | active | done

Goal: <one line>.

- [ ] step
- [ ] step `[tier: low | med | high]`
```

Create and commit tickets and plans on `main`. Before executing a plan, create a
branch named after its slug unless a more specific name is useful or Daniel
explicitly chooses the current branch.

Keep the checkboxes current while executing. A `done` plan means its execution
is complete; closeout may still include harvesting durable facts into `docs/`
and recording the outcome in the backlog's `## Closed` section. Daniel decides
whether to delete the completed plan or move it to `thoughts/plans/archive/`; do
not choose its disposition automatically.

Plan coding tasks for delegation and routing, not only sequencing. Give each
task enough context to execute without reconstructing the design: boundaries,
dependencies, risk, acceptance, and verification.

Delegate selectively. Delegation pays for substantial, independently specifiable
tasks when its expected benefit exceeds the coordination cost; keep small local
fixes found during wiring and integration with the coordinating agent.

- `[tier: low]` — mechanical, local, and fully specified.
- `[tier: med]` — scoped implementation or refactor with a written contract.
- `[tier: high]` — architectural, cross-cutting, stateful, destructive, or
  otherwise judgment-heavy; keep with the coordinating agent by default.

Use the tier to choose the lowest-power model class and effort that comfortably
fits the task. The executor may raise the tier when new complexity appears. The
coordinating agent owns integration and final verification.

## Supporting Notes

Use `thoughts/research/` for investigation and `thoughts/reviews/` for review
findings only when the work warrants separate notes. Prefer names based on the
same `<id>` so related files sort and search together.
