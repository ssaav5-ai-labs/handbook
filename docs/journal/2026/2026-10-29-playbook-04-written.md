---
type: journal
title: Playbook 04 written - Argo CD from Git, secrets with SOPS and age
description: Wrote the Argo CD playbook for the two-node k3s cluster - a slim, self-managed Argo CD in a new homelab-gitops repo, and the decision to keep secrets in Git with SOPS, age and KSOPS.
domain: platform
tags: [argocd, gitops, sops, age, ksops, playbook]
status: active
created: 2026-10-29
updated: 2026-10-29
visibility: public
reuse: lab-specific
related: [../../../playbooks/04-argocd/PLAYBOOK.md, ../../decisions/0019-gitops-with-argo-cd-app-of-apps.md, ../../decisions/0020-secrets-in-git-with-sops-age-ksops.md]
blog: candidate
---

# 2026-10-29: Playbook 04 written - Argo CD from Git, secrets with SOPS and age

## Goal
Have playbook 04 ready right after playbook 03, so everything that runs on the cluster from now on comes from Git.

## What I did
- Wrote `playbooks/04-argocd`: new public repo `homelab-gitops`, Argo CD installed once with Helm (chart `10.11.6`, Argo CD `v3.5.6` at the time of writing; the run looks the versions up again), then app-of-apps with Argo CD managing itself, a SOPS canary secret, CI that refuses plaintext secrets, and self-heal drills.
- Sized Argo CD for 4.5 GB nodes: controller, repo server, server and Redis only; Dex, notifications and the ApplicationSet controller off; memory requests set and checked against real use in the run.
- Proposed [ADR-0019](../../decisions/0019-gitops-with-argo-cd-app-of-apps.md) (slim, self-managed Argo CD) and [ADR-0020](../../decisions/0020-secrets-in-git-with-sops-age-ksops.md) (SOPS + age, KSOPS in the repo server). ADR-0018 is reserved for the blog plan.
- Applied the lessons of the playbook 02 and 03 runs to the new secret, the age key: it sits in a Windows folder mounted into the container (like the kubeconfig), the agent creates it without seeing it, `opencode.json` denies reading it and running `sops decrypt`, and every step that shows a secret is done by the human in a second terminal.
- `RUNNING.md`: the "never print secrets" rule now names the age key, Kubernetes Secret data and decrypted SOPS files.
- Fixed the decision log (ADRs 0015 to 0017 were accepted in their files but still `proposed` in the index) and the catalog (02 and 03 done).

## What broke and how I fixed it
Nothing ran yet. Known risks for the run: routers that block DNS answers pointing at private addresses (nip.io), and chart value keys that move between Argo CD chart versions (the playbook makes the agent read the pinned chart's `values.yaml`).

## Decisions made (link ADRs)
- [ADR-0019](../../decisions/0019-gitops-with-argo-cd-app-of-apps.md), proposed.
- [ADR-0020](../../decisions/0020-secrets-in-git-with-sops-age-ksops.md), proposed.

## Next
Merge this, then run playbook 04.
