# Agent Skills

Repository-local Agent Skills provide optional ways of working with the project.
They may guide an interview, review, investigation, or other focused activity
without requiring a ticket or plan of their own.

Skills supplement the repository workflow; they do not replace `AGENTS.md`,
durable documentation, backlog state, plans, quality gates, or Daniel's
decisions. Use a skill when its interaction model fits the work, and keep the
result in the repository only when it produces project state worth preserving.

Installed skills are pinned in `skills-lock.json` and stored under
`.agents/skills/`. Harness-specific paths may link to that shared copy. Review
third-party instructions and changes before installing or updating them. Keep
installed third-party copies unchanged; update them through the skill manager.

## Current Pilot

`grilling`, sourced from
[`mattpocock/skills`](https://github.com/mattpocock/skills), is the first
repo-local skill. It stress-tests an idea or decision through one recommended
question at a time and does not act until shared understanding is confirmed.

Use it for deliberate decision refinement. Ordinary backlog work and feature
execution do not need to invoke it.
