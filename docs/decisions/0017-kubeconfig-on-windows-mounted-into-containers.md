---
type: adr
title: Keep the cluster kubeconfig on Windows and mount it into every dev container
description: The k3s kubeconfig lives in %USERPROFILE%\.kube and is bind-mounted into dev containers; the lab SSH key lives in a shared Docker volume.
domain: workstation
tags: [workstation, devcontainer, kubeconfig, ssh, k3s]
status: accepted
created: 2026-10-27
updated: 2026-10-29
visibility: public
reuse: portable
related: [0006-local-repo-layout.md, 0015-k3s-embedded-etcd-server-and-agent.md, ../domains/workstation/index.md, ../../playbooks/03-k3s/PLAYBOOK.md]
supersedes: []
superseded_by: []
blog: none
---

# 0017. Keep the cluster kubeconfig on Windows and mount it into every dev container

## Context
`kubectl` runs in dev containers on the Windows laptop, one container at a time, and containers get rebuilt. Several repos (`homelab-infra`, `homelab-gitops`, `ai-factory`) need the same cluster access. The scripts in `homelab-infra` also need the lab SSH key. Docker Desktop shows files on Windows bind mounts as world-readable, and `ssh` refuses private keys like that.

## Options considered
1. **Copy into each container by hand:** nothing to build; lost on every rebuild, and copies drift.
2. **Kubeconfig in the repo folder (git-ignored):** one ignore mistake publishes cluster-admin credentials.
3. **Kubeconfig in `%USERPROFILE%\.kube`, bind-mounted to `/home/vscode/.kube`; SSH key in a named Docker volume `homelab-ssh` mounted at `/home/vscode/.ssh`:** one copy of each, shared by all containers, kept across rebuilds.

## Decision
Option 3, added to the base template in the `workstation` repo and to `homelab-infra`. `kubectl` doesn't check file permissions, so the bind mount is fine for the kubeconfig; the SSH key keeps Linux permissions in the volume.

## Consequences
- After a rebuild, `kubectl` works straight away; the SSH key is copied into the volume once.
- `%USERPROFILE%\.kube` must exist before a container starts, or the mount fails.
- The kubeconfig is a cluster-admin credential on the laptop's disk; laptop disk encryption (BitLocker) matters, and per-user, less-privileged access comes with SSO later.

## In a team or enterprise setting
No long-lived admin kubeconfigs on laptops: use OIDC (for example via the cloud's or an identity provider's kubectl plugin) with short-lived tokens and RBAC per team, and keep break-glass admin credentials in a vault.
