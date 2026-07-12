# Reconciliation

For dynamic systems, prefer desired-versus-actual convergence over one-shot
imperative mutation.

1. Represent desired state.
2. Read or compute actual state.
3. Diff desired and actual.
4. Apply the smallest safe change.
5. Verify the result.
6. Remain idempotent and safe to rerun.

Nix describes much of the desired system, but not all operational state. Disk
contents, backups, secrets, workload data, running services, remote systems, and
migrations need explicit observation, transition, and verification.

Every stateful workflow should define:

- ownership: which system is authoritative;
- observation: how actual state is measured;
- transition: how drift is corrected;
- safety: preview, confirmation, rollback, and failure behavior;
- verification: evidence that convergence succeeded;
- repetition: what happens when the operation runs again.

Use this model for host configuration, storage, backups, deployments, virtual
machines, containers, services, and other dynamic systems.

Kubernetes controllers and Terraform plan/apply workflows are useful conceptual
models: declare intent, observe or refresh actual state, show a plan, converge,
and verify. Local precedents include Daniel's `dotfiles` reconcilers for package
and configuration management, and `qcic` experiments in monitoring, alerting,
and self-healing. Reuse their lessons without forcing their implementations into
this repository.
