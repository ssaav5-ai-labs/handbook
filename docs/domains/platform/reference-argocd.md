---
type: reference
title: Argo CD reference
description: Versions, what's enabled and why, and memory settings for the self-managed Argo CD on the k3s cluster.
domain: platform
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-10-29
related: [../../decisions/0019-gitops-with-argo-cd-app-of-apps.md, ../../decisions/0020-secrets-in-git-with-sops-age-ksops.md, howto-secrets-sops.md, runbook-rebuild-argocd.md, ../../../playbooks/04-argocd/PLAYBOOK.md]
---

# Argo CD reference

## Versions

| Thing | Version |
|---|---|
| Argo CD (chart appVersion) | v3.5.6 |
| argo-helm chart | 10.11.6 |
| KSOPS | v4.5.1 |

Versions are pinned in `homelab-gitops/bootstrap/versions.env` (`ARGOCD_CHART_VERSION`, `KSOPS_VERSION`). CI (`scripts/check-versions.sh`) fails if the chart `targetRevision` in `apps/argocd.yaml` or the `viaductoss/ksops` tag in the values drifts from them.

## What's on and off

| Component | State | Why |
|---|---|---|
| Application controller | on (1 replica) | syncs applications |
| Repo server | on (1 replica) | renders manifests; runs KSOPS for SOPS decryption |
| Server (web UI + API) | on (1 replica) | shows sync state and diffs |
| Redis | on (1 replica) | cache for controller and server |
| ApplicationSet controller | off (0 replicas) | app-of-apps doesn't need it; turn on when apps are generated from folders |
| Dex | off | single user, no SSO |
| Notifications | off | no chat/webhook sink yet |

k3s keeps managing its bundled Traefik, ServiceLB, local-path and metrics-server; settings for them go into this repo as `HelmChartConfig` objects when needed.

## Network

- UI: `https://argocd.192.168.86.211.nip.io` — Traefik terminates TLS with its built-in self-signed certificate; accept the certificate warning in the browser. Argo CD serves plain HTTP inside the cluster (`server.insecure: true`).
- Admin password lives in the password manager only; the initial `argocd-initial-admin-secret` was deleted. CLI access uses the kubeconfig via `argocd ... --core`, not this password.
- Argo CD polls the repo every 3 minutes (`timeout.reconciliation: 180s`); there's no webhook because the cluster isn't reachable from GitHub. A "Refresh" in the UI is immediate.

## Memory settings

Final settings after `kubectl top pods` (playbook 04 step 4):

| Component | requests | limit (memory) | actual (top) |
|---|---|---|---|
| controller | 100m / 256Mi | 768Mi | ~36Mi |
| repo server | 50m / 128Mi | 512Mi | ~25Mi |
| server | 25m / 64Mi | 256Mi | ~59Mi |
| Redis | 25m / 32Mi | 128Mi | ~9Mi |

No CPU limits — they throttle; requests are enough on a lab cluster. Total steady-state is well under 1 GiB.

## Secrets

KSOPS decrypts `*.enc.yaml` files while the repo server renders manifests. The age private key is mounted from the `sops-age` Secret at `/home/argocd/.config/sops/age/keys.txt` (`SOPS_AGE_KEY_FILE`). See [howto-secrets-sops.md](howto-secrets-sops.md).

## Upgrading Argo CD

1. Bump `ARGOCD_CHART_VERSION` in `bootstrap/versions.env` and `targetRevision` in `apps/argocd.yaml` together.
2. Only change the values at the same time if the chart's defaults changed; otherwise leave `bootstrap/argocd/values.yaml` alone.
3. CI (`scripts/check-versions.sh`) fails if the two don't match.
4. Merge the PR and wait up to 3 minutes — Argo CD upgrades itself.

## Why argocd has prune: false

A bad change must never make Argo CD delete its own pieces. The `argocd` Application has `prune: false`; every other app has `prune: true`.
