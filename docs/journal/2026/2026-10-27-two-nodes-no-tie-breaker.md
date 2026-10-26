---
type: journal
title: Two nodes for now, no tie-breaker
description: A third Proxmox node is coming but not chosen, so the cluster runs on two nodes without a Raspberry Pi QDevice and the playbooks go ahead.
domain: proxmox
tags: [hardware, cluster, quorum, capacity]
status: active
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: lab-specific
related: [../../decisions/0013-two-nodes-without-qdevice.md, ../../domains/proxmox/howto-add-node.md, ../../../playbooks/02-proxmox/PLAYBOOK.md]
blog: candidate
---

# 2026-10-27: Two nodes for now, no tie-breaker

## Goal
Decide how to run the lab while the third Proxmox machine is still being chosen, without stalling playbook 02, which is half-run on `pve01` and `pve02`.

## What I did
- Considered a 16 GB Chromebox as `pve03` and drafted its preparation (MrChromebox UEFI firmware, write protect, NIC and power checks). Kept that as a how-to for whichever machine comes: [add a Proxmox node](../../domains/proxmox/howto-add-node.md).
- Dropped the Raspberry Pi QDevice: building a temporary tie-breaker isn't worth the time when a third node is coming.
- Replaced playbook 02's QDevice step with the two-node failure mode: no HA, one reboot at a time, and `pvecm expected 1` on the survivor when a node is really down, with a drill.
- Made steps 4 to 8 work on whichever nodes exist, so the third node is picked up by re-running the playbook.

## What broke and how I fixed it
Nothing; no hardware changed.

## Decisions made (link ADRs)
- [ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md): two nodes without a QDevice until a third node is chosen; Pis on Uptime Kuma. Langfuse stays on Langfuse Cloud ([ADR-0012](../../decisions/0012-langfuse-cloud-until-capacity.md)). The provisioning ADR planned in playbook 02 moves to 0014.

## Next
- Finish playbook 02 on `pve01` and `pve02`, then playbook 03: k3s server with embedded etcd on `k3s-01`, agent on `k3s-02`.
- When the third machine is picked: run the how-to, then re-run playbook 02.
