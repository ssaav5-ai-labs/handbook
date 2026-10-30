---
type: howto
title: How to manage secrets with SOPS, age and KSOPS
description: Encrypting, editing and rotating Kubernetes Secrets committed to the public homelab-gitops repo, decrypted by Argo CD with KSOPS.
domain: platform
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-29
updated: 2026-10-29
related: [../../decisions/0020-secrets-in-git-with-sops-age-ksops.md, reference-argocd.md, runbook-rebuild-argocd.md, ../../../playbooks/04-argocd/PLAYBOOK.md]
---

# How to manage secrets with SOPS, age and KSOPS

## How it works

Secrets live in `homelab-gitops/platform/<app>/` as plain Kubernetes `Secret` manifests in files named `*.enc.yaml`. SOPS encrypts only their `data` and `stringData` values (see `.sops.yaml`), so the name, namespace and keys stay human-readable in diffs. KSOPS (running in Argo CD's repo server) decrypts them while rendering manifests. The private age key lives in the `sops-age` Secret in the `argocd` namespace.

## Add a new secret

1. **Agent writes the scaffolding:** an Application in `apps/<app>.yaml`, and under `platform/<app>/` a `namespace.yaml`, `kustomization.yaml`, and `secret-generator.yaml` (a `kind: ksops` generator referencing the encrypted file). It leaves a placeholder for `secret.enc.yaml`.
2. **You fill the secret's values** in your terminal (not the agent's):

   ```bash
   sops edit platform/<app>/secret.enc.yaml
   ```

   SOPS opens your editor with the decrypted file. Write the Secret under `stringData:` (or `data:` for base64). Save and close — SOPS re-encrypts it. Example:

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: example
     namespace: <namespace>
   type: Opaque
   stringData:
     api-key: "sk-..."
   ```

3. **Commit and PR.** CI (`scripts/check-secrets.sh`) verifies the file has a `sops:` block and encrypted values before merge.

## Edit an existing secret

```bash
sops edit platform/<app>/secret.enc.yaml
```

Make changes, save, close, commit. Argo CD picks up the change within 3 minutes.

## Rotate the age key

1. Generate a new key: `age-keygen -o /tmp/new-key.txt`.
2. Add its public key (the `age1...` line) to `.sops.yaml` before the old one.
3. Re-encrypt every file for both keys:

   ```bash
   find platform -name '*.enc.yaml' -exec sops updatekeys {} \;
   ```

4. Verify all files can be decrypted with the old key (still works) and the new key: `sops --decrypt platform/<app>/secret.enc.yaml` should succeed with only the new key in `$SOPS_AGE_KEY_FILE`.
5. Replace the `sops-age` Secret with the new key.
6. Remove the old key from `.sops.yaml` and run `sops updatekeys` again.
7. Update the password manager entry.

## What if the key is lost

If the private key is gone (e.g. the password manager backup is lost and the cluster is rebuilt):

1. Generate a new key.
2. Re-create **every** secret's values from scratch (the encrypted files can't be decrypted without the old key).
3. Keep the backup in the password manager.