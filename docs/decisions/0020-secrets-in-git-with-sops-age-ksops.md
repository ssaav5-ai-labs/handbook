---
type: adr
title: Keep secrets in Git, encrypted with SOPS and age, decrypted by KSOPS in Argo CD
description: Secrets are committed as SOPS-encrypted files (values only) for one lab age key; Argo CD's repo server decrypts them with KSOPS while rendering; the private key lives in a password manager, a Windows folder mounted into dev containers, and one cluster Secret.
domain: platform
tags: [secrets, sops, age, ksops, argocd, gitops]
status: proposed
created: 2026-10-29
updated: 2026-10-29
visibility: public
reuse: portable
related: [0017-kubeconfig-on-windows-mounted-into-containers.md, 0019-gitops-with-argo-cd-app-of-apps.md, ../domains/platform/howto-secrets-sops.md, ../../playbooks/04-argocd/PLAYBOOK.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0020. Keep secrets in Git, encrypted with SOPS and age, decrypted by KSOPS in Argo CD

## Context
With GitOps ([ADR-0019](0019-gitops-with-argo-cd-app-of-apps.md)), apps need their secrets (API keys, passwords) to come from the same public repo, or the cluster can't be rebuilt from Git. Until now, the only lab secrets were the Proxmox token and the k3s token in `homelab-infra/.env` and a password manager. Two playbook runs leaked a token into an AI agent's transcript, so whatever is chosen must work without the agent ever seeing a value. No cloud KMS or vault is available, and the lab has no spare memory for one.

## Options considered
1. **Sealed Secrets:** encrypt with the cluster's public key, a controller decrypts. Simple and popular; the private key is created inside the cluster, so a rebuilt cluster can't read old secrets unless that key was backed up, and nobody can decrypt a file outside the cluster.
2. **SOPS + age, decrypted by an operator** (`sops-secrets-operator`): a custom `SopsSecret` resource and one more controller pod.
3. **SOPS + age, decrypted by KSOPS** in Argo CD's repo server while it renders manifests: no extra pod, plain `Secret` manifests encrypted in Git, decryptable on the laptop with the same key.
4. **External Secrets Operator + a vault** (Vault, Bitwarden Secrets Manager, a cloud secret manager): the enterprise pattern; needs a vault running or a cloud account, and more memory.

## Decision
Option 3. Files named `*.enc.yaml` are encrypted by SOPS for one lab age key (rules in `.sops.yaml`), values only, so diffs stay readable. Argo CD's repo server gets the `ksops` and `kustomize` binaries from an init container and the private key from the Secret `sops-age`. The private key exists only in the password manager, in `%USERPROFILE%\.sops-age\keys.txt` (mounted into dev containers as `SOPS_AGE_KEY_FILE`), and in that Secret. The AI agent never reads or decrypts it: `opencode.json` denies reading the key file and running `sops decrypt`; you write real values with `sops edit` in your own terminal. CI fails on any `kind: Secret` outside an encrypted file.

## Consequences
- Lose the key and every encrypted value must be re-created. The password manager copy is the backup.
- Rotating the key: new key, add it to `.sops.yaml`, `sops updatekeys` on every file, replace the `sops-age` Secret, then remove the old key.
- The repo server's init container adds a few seconds to its start and one more image to keep current (pinned, checked in CI).
- Anyone with admin access to the cluster can read the decrypted Secrets; that's true of every option here.
- Later: move `homelab-infra/.env` into a SOPS file with the same key, so the k3s token is backed up in Git too.

## In a team or enterprise setting
External Secrets Operator reading from a central vault or cloud secret manager, with per-team access policies, audit logs and automatic rotation; SOPS stays useful for bootstrap secrets, encrypted for a cloud KMS key instead of a personal age key, with several recipients so no single person holds the only key.
