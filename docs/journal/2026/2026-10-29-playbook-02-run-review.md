---
type: journal
title: Review of the playbook 02 run
description: Lessons from the exported playbook 02 session - a secret in the transcript, a missing guest agent, and three UI surprises - and the playbook fixes they produced.
domain: proxmox
tags: [proxmox, review, secrets, opentofu, backups]
status: active
created: 2026-10-29
updated: 2026-10-29
visibility: public
reuse: portable
related: [../../../playbooks/02-proxmox/PLAYBOOK.md, ../../../playbooks/RUNNING.md, 2026-10-23-playbook-02.md]
blog: candidate
---

# 2026-10-29: Review of the playbook 02 run

## Goal
Mine the exported OpenCode session of the first playbook 02 run for fixes before playbook 03 starts.

## What I did
Checked the export for secrets first, redacted it, then read every step for friction and failures.

## What broke and how I fixed it
- **A secret reached the transcript.** The first run had put the Proxmox token in `terraform.auto.tfvars`; later the agent ran `cat` on that file and pasted the value into `tofu plan` commands, so it was sent to the model and saved in the export. The token was rotated and moved to `.env`. Fix: a new rule in `RUNNING.md` that agents never print files that may hold secrets and never put a secret on a command line.
- **The broad secret check cried wolf.** `grep "PVEAPIToken|=[0-9a-f-]{36}"` matched 35 times, mostly harmless (curl commands naming the variable, disk and VM UUIDs). The playbooks now use patterns that only match real values.
- **Every VM create or change took 15 minutes.** The Debian cloud image has no QEMU guest agent, so the OpenTofu provider waited for it until its timeout. Fix: playbook 02 step 6 installs it into the image with `virt-customize`; playbook 03 step 1 installs it on the existing VMs.
- **Node drill:** a node that is off can't be started from the Proxmox UI; it needs its power button. Step 3 now says so.
- **Backup job:** *Create* stays greyed out until a VM is ticked. The step also removes a leftover job from the first run and makes the local `usb-backup` storage (which shares its directory with the other node's NFS storage) restore-only with `keep-all`, so two storages can't prune the same files.
- **Restore test:** the VMs use a serial console, so the default console shows only "starting serial terminal"; use **Console → xterm.js**.
- **Container to Proxmox API timeouts:** a few `curl` and `tofu plan` calls from the dev container hung for minutes, then worked again later. Not reproduced; watch for it in playbook 03.

## Decisions made (link ADRs)
None new. The USB disks are split into ~600 GB backup and ~316 GB share partitions (recorded in `reference-proxmox.md` during the run).

## Next
Merge the playbook 03 patch and run it. Check on `pve01` that `grep -E '^vzdump|storage|vmid' /etc/pve/jobs.cfg` shows only the two cross-node jobs.
