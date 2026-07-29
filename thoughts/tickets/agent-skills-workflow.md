# agent-skills-workflow — Evaluate Agent Skills in the Workflow

Evaluate whether a small, curated set of reputable Agent Skills improves
planning, decision-making, review, and implementation without making the
repository workflow harder to understand or less portable. Learn from strong
existing skills first; refine or author personal skills only where real use
reveals an unmet need.

## Experiment Already Started

On 2026-07-29, `grilling` from `mattpocock/skills` became the first repo-local
skill. It is a useful initial case because its guided decision interview can be
used independently of task planning.

The installation establishes a pilot, not a commitment to reorganize the
workflow around third-party skills or to build a personal skill library.

## Questions

- Which recurring activities materially improve when guided by a skill?
- Which skills are trustworthy, maintained, concise, and compatible with the
  agent harnesses in use?
- What security review is appropriate before installing skill instructions or
  scripts?
- When should a skill remain optional tooling, and when should its useful method
  become repository policy?
- How should installed skills be reviewed, updated, pinned, and removed?
- Which outcomes belong only in conversation, and which should be harvested into
  a ticket, plan, design, or durable documentation?
- Can skills reduce planning overhead without obscuring project state or
  bypassing quality and safety gates?
- When is adapting or authoring a personal skill better than continuing to use a
  reputable upstream skill?
- Which Agent Skills features are portable, and which harness-specific
  extensions should be isolated?

## Boundaries

- Keep repository state and policy understandable without any skill installed.
- Adopt skills individually from observed value, not as a wholesale framework.
- Do not require a ticket or plan merely to use an interviewing or reasoning
  skill.

## Possible Evolution

If repeated use exposes a stable need that reputable existing skills do not
serve, create the smallest useful personal skill. The shared docs/thoughts
workflow is one candidate, after its common core has been proven in nix-garden
and Prosodio.

A personal workflow skill should:

- point to shared canonical material without hiding repository-specific policy;
- decide where that canonical source lives and how adopters detect updates while
  retaining deliberate local adaptations;
- preserve local quality gates, commands, and safety constraints;
- install and update reliably across the agent harnesses in use;
- define review, versioning, drift detection, rollback, and removal;
- be exercised repo-locally in nix-garden and Prosodio before wider use.

## Next Experiment

Use `grilling` on a real decision, note where it helps or creates friction, and
let that evidence guide selection of the next reputable skill, any workflow
change, or eventual personal skill.
