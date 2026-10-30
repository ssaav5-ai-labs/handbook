---
type: runbook
title: Rebuild Argo CD on an empty cluster
description: Steps to recover Argo CD and all its apps from the homelab-gitops repo after a complete cluster rebuild.
domain: platform
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-10-29
related: [reference-argocd.md, howto-secrets-sops.md, ../../decisions/0019-gitops-with-argo-cd-app-of-apps.md, ../../decisions/0020-secrets-in-git-with-sops-age-ksops.md, ../../../playbooks/04-argocd/PLAYBOOK.md]
---

# Rebuild Argo CD on an empty cluster

**Status: UNTESTED.** Written during playbook 04; rehearse it on a rebuilt cluster if the cluster is ever rebuilt.

## When to use

The k3s cluster was rebuilt from scratch (via playbook 03) and Argo CD needs to come back from the `homelab-gitops` repo.

## Prerequisites

- k3s is running, nodes are `Ready`, kubeconfig is in `%USERPROFILE%\.kube`.
- The age private key is in `%USERPROFILE%\.sops-age\keys.txt` (from the password manager).
- A dev container is running in `homelab-gitops`.

## Steps

1. **Restore the age key.** Copy the age private key from the password manager into `%USERPROFILE%\.sops-age\keys.txt` (Windows). The dev container mounts it at `/home/vscode/.sops-age/keys.txt`.

2. **Run the bootstrap script (first pass).**

   ```bash
   ./bootstrap/install.sh
   ```

   This creates the `argocd` namespace, the `sops-age` Secret, and installs Argo CD from the Helm chart. The script skips the project and root app because `bootstrap/project.yaml` and `bootstrap/root.yaml` aren't on `origin/main` yet at this point. But wait – they should be on main now (they were merged in step 7). If they are, this first pass also applies them.

3. **Wait for Argo CD to sync.** `kubectl -n argocd get applications` should show `root`, `argocd`, and any other apps as `Synced`/`Healthy`.

4. **First login.** The chart creates an initial admin secret. Follow step 5 of playbook 04:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
   ```
   Log in at `https://argocd.192.168.86.211.nip.io`, change the password, delete the initial secret.

5. Verify all applications are `Synced` and `Healthy`.

If the cluster has no `main` branch in Git (e.g. it's a completely new repo clone), you'll need to push the repo contents first, but normally `main` already exists.