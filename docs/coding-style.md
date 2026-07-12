# Coding style

Conventions agents don't adopt by default. Will grow.

## Top-down: caller before callee

Entry point first, helpers below. This is a reading-order convention, not a
TypeScript-specific one; apply it across languages and command files unless the
language prevents it.

```txt
// ENTRY POINT
if (import.meta.main) {
  await main();
}

// MAIN
async function main(): Promise<void> {
  await tokenize();
  await buildIndex();
  await findAnchors();
  await score();
}

async function tokenize(): Promise<void> {
  // Convert cues to words
}
```

In a `Justfile`, put public entry recipes first. Put their private helper
recipes below them in the order needed to understand each entry recipe.

## Reconciliation: desired vs actual

Where it fits, model state as desired vs actual and converge — not one-shot
imperative mutation.

- Represent desired state.
- Read or compute actual state.
- Reconcile the diff; make it idempotent and re-runnable.

## Keep commands direct

Keep commands directly in Just recipes while they remain clear. Scripts are an
escape valve for real complexity, reuse, or defensive bootstrap work that must
run with minimal assumptions; do not create one-line wrapper scripts.
