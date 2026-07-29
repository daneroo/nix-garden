# Agent Skills

Repository-local Agent Skills provide optional ways of working with the project.
They may guide an interview, review, investigation, or other focused activity
without requiring a ticket or plan of their own.

Skills supplement the repository workflow; they do not replace `AGENTS.md`,
durable documentation, backlog state, plans, quality gates, or Daniel's
decisions. Use a skill when its interaction model fits the work, and keep the
result in the repository only when it produces project state worth preserving.

Installer-managed skills are pinned in `skills-lock.json` and stored under
`.agents/skills/`. Harness-specific paths may link to that shared copy. Review
third-party instructions and changes before installing or updating them. Keep
installer-managed copies with a tracked upstream unchanged; update them through
the skill manager. This currently applies only to `grilling`. Skills authored in
this repository remain subject to its normal formatting rules.

Prefer reputable, reviewed existing skills while learning what is useful. A
personal skill is a later refinement for a proven need that existing skills do
not serve, not a separate starting track.

## Current Pilot

`grilling`, sourced from
[`mattpocock/skills`](https://github.com/mattpocock/skills), is the first
repo-local skill. It stress-tests an idea or decision through one recommended
question at a time and does not act until shared understanding is confirmed.

Use it for deliberate decision refinement. Ordinary backlog work and feature
execution do not need to invoke it.
