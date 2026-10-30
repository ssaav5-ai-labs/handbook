---
type: journal
title: Review of the playbook 04 run
description: The first playbook run where no secret reached the agent - the age key read was refused - plus Git, CI and timing fixes folded back into playbook 04.
domain: platform
tags: [argocd, sops, review, secrets, opencode]
status: active
created: 2026-10-30
updated: 2026-10-30
visibility: public
reuse: portable
related: [../../../playbooks/04-argocd/PLAYBOOK.md, ../../../playbooks/RUNNING.md, 2026-10-29-playbook-04.md, 2026-10-29-playbook-03-run-review.md]
blog: candidate
---

# 2026-10-30: Review of the playbook 04 run

## Goal
Check the exported playbook 04 session for secrets and fold its friction back into the playbook.

## What I did
Ran the value-only secret check on the export, then read every command the agent ran and every failure.

## What went right
- **No secret reached the agent.** The agent tried to open the age key with its read tool during step 3; `opencode.json` refused it (`*/.sops-age/*` and `*keys.txt` deny rules). The private key exists only in the password manager, the Windows folder and the cluster Secret. The admin password and the decrypted canary were only ever shown in Shawn's own terminal.
- Argo CD idles at about 130 MiB (controller 36, repo server 25, server 59, Redis 9), far below the 4.5 GB nodes' budget.
- All four drills (deleted Secret, scaled-down server, change through Git, agent node reboot) recovered without help.

## What broke and how I fixed it
- **The secret check cried wolf.** `BEGIN OPENSSH` matched 5 times: the playbook quotes its own check pattern, and the export contains every read of it. Every real OpenSSH private key body starts with `b3BlbnNzaC1rZXktdjE`; the check now looks for `BEGIN OPENSSH PRIVATE KEY-----` followed by `b3Bl`, in playbooks 03 and 04.
- **Local `main` diverged after the first squash-merge.** The agent committed on `main`, then branched; the squashed commit on GitHub differed, and `git pull` refused. Recovered with `git reset --hard origin/main`. Fix: branch before committing, and `pull.ff only`.
- **CI, three first-run failures:** shellcheck needs `-x` for the sourced `versions.env`; the CRDs catalog had no Argo CD schemas, so kubeconform uses `-ignore-missing-schemas`; `check-secrets.sh` looked for the `sops:` block with `head -5`, but SOPS writes it at the end of the file.
- **"Namespace not found" right after a merge** was the root app not having polled Git yet (up to 3 minutes). The playbook now says so and shows how to force a refresh.
- **`kubectl top` said `NotFound`** for a pod a few seconds old; metrics need about a minute.
- **Change through Git:** the human only runs `sops edit` (with `EDITOR=nano`) in their own terminal; the agent does the branch, commit and PR in the shared folder.
- **New container, no Git identity:** the agent set `user.name`/`user.email` per repo. Step 1 now sets them globally if missing.

## Decisions made (link ADRs)
None new. [ADR-0019](../../decisions/0019-gitops-with-argo-cd-app-of-apps.md) and [ADR-0020](../../decisions/0020-secrets-in-git-with-sops-age-ksops.md) were accepted in the run.

## Next
Lower the memory requests in `homelab-gitops` once a few apps run (controller 256 Mi and repo server 128 Mi requested vs about 30 Mi used), then playbook 05.
