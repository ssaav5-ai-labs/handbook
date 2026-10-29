---
type: adr
title: Run the cluster from Git with a slim, self-managed Argo CD (app-of-apps)
description: Argo CD is installed once with Helm, then manages itself and every other app from the homelab-gitops repo through a root app; Dex, notifications and ApplicationSet are off, and k3s keeps its bundled components.
domain: platform
tags: [argocd, gitops, helm, app-of-apps, k3s]
status: proposed
created: 2026-10-29
updated: 2026-10-29
visibility: public
reuse: portable
related: [0015-k3s-embedded-etcd-server-and-agent.md, 0020-secrets-in-git-with-sops-age-ksops.md, ../../playbooks/04-argocd/PLAYBOOK.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0019. Run the cluster from Git with a slim, self-managed Argo CD (app-of-apps)

## Context
From playbook 05 on, everything that runs on the k3s cluster (monitoring, the LLM gateway, Hermes, the SRE agents, Backstage) should be declared in Git, reviewed in a PR and applied by a controller, so the cluster can be rebuilt from the repo and every change has a history. The nodes have about 4.5 GB each, with roughly 3.4 GB free on `k3s-01` after k3s. The setup should also be the kind an employer or client would recognise.

## Options considered
1. **`kubectl apply` / `helm` from CI or by hand:** no extra pods; no drift detection, the cluster needs to be reachable from CI, and nothing repairs hand edits.
2. **Flux:** lighter (a few controllers, no UI), Kubernetes-native, good SOPS support built in; no UI, so state and diffs are read from the CLI.
3. **Argo CD, default install:** the most widely used GitOps tool, with a UI that shows sync state and diffs; seven components and more than 1 GB of RAM by default.
4. **Argo CD, slim:** controller, repo server, server (UI) and Redis only, with explicit memory requests; Dex, notifications and the ApplicationSet controller off until needed.

## Decision
Option 4. Helm installs Argo CD once (`bootstrap/install.sh`); a root Application then syncs every file in `apps/`, including `apps/argocd.yaml`, which manages Argo CD from the same chart version and values file (app-of-apps, self-managed). Apps sync automatically with self-heal; `prune` is on except for Argo CD itself. Argo CD polls the public repo every 3 minutes (no webhook, the cluster isn't reachable from GitHub). k3s keeps managing its bundled Traefik, ServiceLB, local-path and metrics-server; settings for them go into this repo as `HelmChartConfig` objects when needed. The UI is served through Traefik on a `nip.io` name until the lab has DNS.

## Consequences
- After the takeover, nobody runs `helm` against the cluster; changes are PRs. An Argo CD upgrade is a version bump in two places that CI keeps equal (`bootstrap/versions.env` and `apps/argocd.yaml`).
- Rebuilding is: k3s, age key, `bootstrap/install.sh` (see `runbook-rebuild-argocd.md`).
- Argo CD costs about half a gigabyte; the playbook records the real number.
- Up to 3 minutes between a merge and the cluster changing; a "Refresh" in the UI is immediate.
- Flux would have been lighter; if memory gets tight before the third node arrives, revisit.

## In a team or enterprise setting
The same pattern scales with ApplicationSets (one app per folder, cluster or tenant), AppProjects per team with RBAC, SSO through Dex or an OIDC provider, notifications to chat, webhooks from the Git host, and a separate management cluster running Argo CD for many workload clusters.
