---
type: explanation
title: Platform
description: Overview of the platform domain - Argo CD, SOPS + age secrets, observability, ingress and certs on the k3s cluster.
domain: platform
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-29
related: [../../decisions/0019-gitops-with-argo-cd-app-of-apps.md, ../../decisions/0020-secrets-in-git-with-sops-age-ksops.md, reference-argocd.md, howto-secrets-sops.md, runbook-rebuild-argocd.md]
---

# Platform

## What exists

Argo CD runs the cluster from Git (app-of-apps, [ADR-0019](../../decisions/0019-gitops-with-argo-cd-app-of-apps.md)). Secrets live in the same repo, encrypted with SOPS and an age key, decrypted in-cluster by KSOPS ([ADR-0020](../../decisions/0020-secrets-in-git-with-sops-age-ksops.md)).

```
GitHub: ssaav5-ai-labs/homelab-gitops (main, PRs + ci)
           |  polls every 3 min
           v
argocd namespace (k3s)
  root -- apps/*.yaml -- argocd        (Argo CD manages itself: chart + values from Git)
                    -- sops-canary   (KSOPS decrypts *.enc.yaml with the age key)
  repo-server + ksops -- Secret sops-age

laptop: dev container -- kubectl, helm, sops, age (key from %USERPROFILE%\.sops-age)
browser -- https://argocd.192.168.86.211.nip.io  (Traefik, self-signed cert)
```

Argo CD runs slim: 129 MiB steady-state (controller ~36 MiB, repo-server ~25 MiB, server ~59 MiB, Redis ~9 MiB). Dex, notifications and ApplicationSet are off until needed.

## Docs

- [Argo CD reference](reference-argocd.md) — versions, what's on/off, memory, upgrade procedure
- [How to manage secrets with SOPS, age and KSOPS](howto-secrets-sops.md)
- [Rebuild Argo CD on an empty cluster](runbook-rebuild-argocd.md) (UNTESTED)
- [ADR-0019](../../decisions/0019-gitops-with-argo-cd-app-of-apps.md) — GitOps with Argo CD app-of-apps
- [ADR-0020](../../decisions/0020-secrets-in-git-with-sops-age-ksops.md) — Secrets in Git with SOPS, age and KSOPS

## Next

Playbook 05: observability and the gateway, deployed as apps in this repo with their secrets in SOPS.
