---
type: adr
title: Argo CD apps delete their resources; stateful data is kept
description: Removing an app from Git cascades deletion of its resources through a resources finalizer, but PVCs and the postgres data they back survive with Delete=false annotations and a StatefulSet retention policy.
domain: platform
tags: [argo-cd, gitops, prune, delete-protection, pvc, stateful-data, postgres]
status: accepted
created: 2026-11-09
updated: 2026-11-09
visibility: public
reuse: portable
related: [0019-gitops-with-argo-cd-app-of-apps.md, 0022-llm-gateway-on-k3s.md, 0023-hermes-on-k3s-pod-as-sandbox.md, 0025-gateway-virtual-keys-with-postgres.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0032. Argo CD apps delete their resources; stateful data is kept

## Context
ADR-0019 runs the cluster from `homelab-gitops` as an app-of-apps: the root app syncs `apps/*.yaml`, and every child app self-heals with `prune: true` (except Argo CD itself). The intended GitOps semantics are that removing an app's file from Git deletes that app and everything it owns, so the cluster always matches the repo and nothing drifts.

That cascade deletion is exactly what we want for stateless workloads, but it is too aggressive for state. Two things hold data that must outlive a redeploy: the `hermes-data` PVC (Hermes' working state and policy) and the postgres StatefulSet volume (gateway virtual keys and spend logs, ADR-0025). If `hermes.yaml` or `llm-gateway.yaml` disappeared from Git, plain pruning would delete their namespaces, which delete their PVCs regardless, and the database would vanish with them.

## Options considered
1. **`prune: false` everywhere:** no accidental deletion, but the cluster stops matching Git, drift is invisible and orphans accumulate — it gives up the core benefit of GitOps.
2. **Keep pruning and back state up separately:** state survives but adds a backup job and restore steps for data that ADR-0025 already chose to rebuild rather than back up.
3. **Keep pruning, but pin deletion behavior per resource:** cascade stateless resources with a finalizer, and opt specific stateful objects out of deletion with `Delete=false` and a StatefulSet retention policy.

## Decision
Option 3, applied in `homelab-gitops` (PR #54):

- Add `finalizers: [resources-finalizer.argocd.argoproj.io]` to the child Applications `hermes`, `llm-gateway`, `monitoring` and `sops-canary`, so deleting one of their files cascades to their resources. Never add it to `root`, `argocd` or `prometheus-operator-crds`: deleting those would tear down Argo CD or the CRDs it needs, so they stay protected from cascade.
- Annotate `argocd.argoproj.io/sync-options: Delete=false` on the `hermes-data` PVC and on the `hermes` and `llm-gateway` Namespace objects. The namespace annotation matters because deleting a namespace deletes its PVCs regardless of any PVC-level setting.
- Set `persistentVolumeClaimRetentionPolicy: { whenDeleted: Retain, whenScaled: Retain }` on the postgres StatefulSet so its `data` PVC survives a StatefulSet deletion or scale-down.
- Add a CI check (`scripts/check-app-finalizers.sh`) that fails if any `apps/*.yaml` except the three exempt apps lacks the resources finalizer.

## Consequences
- Removing an app from Git still deletes its stateless resources, so Git remains the source of truth.
- Stateful data survives: `hermes-data` and the postgres PVC are retained when their owning app or StatefulSet is removed, and can be reattached on redeploy or cleaned up by hand.
- Retained PVCs are not free: an orphaned PVC keeps its volume and costs a manual cleanup step. The `Delete=false` annotation is the point, not a bug — revisit if the lab accumulates stale volumes.
- The CI check makes the finalizer explicit and reviewable; adding a new app without it fails CI until the protect-or-exempt choice is made.
- `root`, `argocd` and `prometheus-operator-crds` stay exempt on purpose; the check documents that decision rather than enforcing a blanket rule.

## In a team or enterprise setting
The same pattern: keep pruning on so Git is authoritative, add a resources finalizer to cascade deletes, and protect state with `Delete=false` on volumes and namespaces plus a PVC retention policy on StatefulSets. At scale, pair this with real snapshots and backups (CSI snapshots, Velero) rather than relying on retained volumes, and put the protect-or-exempt check in policy-as-code for every new app.
