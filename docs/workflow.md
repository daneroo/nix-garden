# Workflow

Backlog -> plan -> implement -> done. Everything in `thoughts/` is transient
except `BACKLOG.md`.

Files in `thoughts/` use lowercase kebab-case. Keep the backlog readable in one
pass; move detail into a ticket when an entry grows beyond a few lines.

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

Document filenames use lowercase kebab-case. Reserve uppercase filenames for
widely recognized repository indexes or control files such as `README.md` and
`BACKLOG.md`; uppercase is a signal and should remain sparse.

## Required Invariants

Each adopting repository names one required quality-gate command in its local
instructions. Plans and agents must run that gate after edits and before
commits; the implementation remains repository-specific. For nix-hardy the gate
is `just pre-commit`, backed by `scripts/pre-commit.sh`. For Prosodio it is
`bun run ci`.

The shared workflow defines the invariant, not a universal command. A copied or
generated workflow must preserve the adopting repository's local command and
must not overwrite repository-specific safety constraints.

## Backlog

`thoughts/BACKLOG.md` is the index of unscheduled work, grouped by theme. Use a
`## Now` section when ordering the next items would be useful.

```md
- [ ] <id> — <short outcome>; ticket: [<id>](tickets/<id>.md)
```

The stable `<id>` is a lowercase kebab-case slug shared by its ticket, design,
and plan. On completion, move the item to a newest-first `## Closed` section
with its date, outcome, and archived-plan link when one remains useful.

## Tickets

`thoughts/tickets/<id>.md` holds working detail for one backlog item: evidence,
constraints, options, and pending decisions. It has no required schema beyond a
clear title. Delete it when the item closes after harvesting durable facts into
`docs/`, code, or the executing plan; Git retains its history.

## Designs

`thoughts/design/<id>-design.md` explains a problem, constraints, alternatives,
decisions, and open questions. A design says what should be built and why; a
plan turns the chosen direction into executable steps.

Consolidate superseded drafts rather than accumulating them. When the design is
settled, harvest durable facts and delete the transient design.

## Plans

Create `thoughts/plans/<id>.md` when work is scheduled:

```md
# <Title>

Status: planned | active | done

Goal: <one line>.

- [ ] step
- [ ] step
```

Keep the checkboxes current while executing. When complete, record the outcome
in the backlog's `## Closed` section. Delete the plan or move it to
`thoughts/plans/archive/` while it remains a useful exemplar or reference.

Plan coding tasks for delegation and routing, not only sequencing. Each task
should provide enough context to select an appropriate subagent model class and
effort level without reconstructing the design. State its boundaries,
dependencies, risk or ambiguity, acceptance criteria, and verification where
they are not obvious. Recommend model or effort when useful, but let the
executor reassess when implementation reveals new complexity.

## Supporting Notes

Use `thoughts/research/` for investigation and `thoughts/reviews/` for review
findings only when the work warrants separate notes. Prefer names based on the
same `<id>` so related files sort and search together.
