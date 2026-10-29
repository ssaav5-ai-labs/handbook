---
type: journal
title: Review of the playbook 03 run
description: The Proxmox token reached the agent again because nothing technical stopped it, and the agent's command guard rails were under a config key OpenCode doesn't read; fixes in opencode.json and playbook 03.
domain: k3s
tags: [k3s, review, secrets, opencode, permissions]
status: active
created: 2026-10-29
updated: 2026-10-29
visibility: public
reuse: portable
related: [../../../playbooks/03-k3s/PLAYBOOK.md, ../../../playbooks/RUNNING.md, 2026-10-29-playbook-03.md, 2026-10-29-playbook-02-run-review.md]
blog: candidate
---

# 2026-10-29: Review of the playbook 03 run

## Goal
Find out how the Proxmox token reached the agent despite the new rule in `RUNNING.md`, and fold the run's fixes back into playbook 03.

## What I did
Checked the export with value-only patterns (only the Proxmox token matched), rotated the token, redacted the export and read it.

## What broke and how I fixed it
- **The agent opened `.env` with its file-read tool** in the first minutes, while checking prerequisites, before any step said to. A written rule doesn't stop that. Fix: `opencode.json` now denies reading `.env`, `*.tfvars`, kubeconfigs and `k3s.yaml`, and denies `cat` of them and `env`/`printenv` in the shell. Copy it into every repo.
- **The command guard rails never applied.** Since playbook 00, `opencode.json` listed them under `permission.shell`; OpenCode reads `permission.bash`, so `rm`, `git push` and `sudo` never asked. Renamed. Check after the change that OpenCode asks before a `git push`, and refuses to read `.env`.
- **Fixes the run made, now in the playbook:** `install.sh` runs in the container and works over SSH; templates end with a newline; the kubelet drop-in must be `99-kubelet-swap.conf` (k3s reads only `.conf`); `sudo` for `zramctl`, `sysctl` and `swapon` over SSH (`/usr/sbin` isn't on the `PATH`); `uptime -s` proves a reboot; no `set -e` in the smoke test.
- **OpenRouter refused requests mid-run** (`402`, in-flight budget): the balance was low. Waiting two minutes and continuing worked.

## Decisions made (link ADRs)
None new.

## Next
Confirm the new permissions in a fresh OpenCode session, then playbook 04.
