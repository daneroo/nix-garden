# concise-agent-docs — Reduce Agent Documentation

Agent guidance is becoming verbose, repetitive, expensive in context, and
unpleasant for humans to read.

## Goal

Make `AGENTS.md` and linked workflow docs in nix-hardy and Prosodio concise
enough to scan and remember.

## Rules

- One fact, one home; link instead of repeating.
- Prefer short bullets and examples over explanatory prose.
- Keep only instructions that change behavior.
- Move rationale and unsettled ideas to tickets.
- Separate shared rules from repo-specific commands.
- Measure line and word-count reductions.
- Preserve safety constraints and quality gates.

## Done

- Both repos are materially shorter and remain complete.
- A human can find the required command and workflow quickly.
- Agents receive no duplicated or speculative guidance.
- Both repository quality gates pass.
