# agent-skills-workflow — Evaluate Agent Skills in the Workflow

Evaluate whether a small, curated set of highly regarded Agent Skills improves
planning, decision-making, review, and implementation without making the
repository workflow harder to understand or less portable.

## Experiment Already Started

On 2026-07-29, `grilling` from `mattpocock/skills` became the first repo-local
skill. It is a useful initial case because its guided decision interview can be
used independently of task planning.

The installation establishes a pilot, not a commitment to reorganize the
workflow around third-party skills.

## Questions

- Which recurring activities materially improve when guided by a skill?
- Which skills are trustworthy, maintained, concise, and compatible with the
  agent harnesses in use?
- When should a skill remain optional tooling, and when should its useful method
  become repository policy?
- How should installed skills be reviewed, updated, pinned, and removed?
- Which outcomes belong only in conversation, and which should be harvested into
  a ticket, plan, design, or durable documentation?
- Can skills reduce planning overhead without obscuring project state or
  bypassing quality and safety gates?

## Boundaries

- Keep repository state and policy understandable without any skill installed.
- Adopt skills individually from observed value, not as a wholesale framework.
- Do not require a ticket or plan merely to use an interviewing or reasoning
  skill.
- Keep the separate `shared-workflow-skill` item focused on authoring and
  distributing Daniel's own reusable repository-workflow skill.

## Next Experiment

Use `grilling` on a real decision, note where it helps or creates friction, and
let that evidence guide selection of the next skill or any workflow change.
