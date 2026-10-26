---
type: adr
title: Run two Proxmox nodes without a QDevice until a third node is chosen
description: The cluster stays at pve01 and pve02 with no Raspberry Pi tie-breaker; losing a node is handled by hand with pvecm expected 1, and a third node joins later.
domain: proxmox
tags: [proxmox, cluster, quorum, k3s, capacity]
status: accepted
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: portable
related: [../domains/proxmox/reference-hardware.md, ../domains/proxmox/howto-add-node.md, ../../playbooks/02-proxmox/PLAYBOOK.md, ../journal/2026/2026-10-26-two-nodes-and-a-pi.md, 0012-langfuse-cloud-until-capacity.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0013. Run two Proxmox nodes without a QDevice until a third node is chosen

## Context
`pve01` and `pve02` have 8 GB each and can't take more RAM. The plan of 2026-10-26 added a Raspberry Pi 3 as a QDevice, a vote-only tie-breaker, so either node could go down without the other losing control. On 2026-10-27 Shawn decided a third machine is coming (a 16 GB Chromebox and other options are being weighed) and that time spent on a temporary Pi tie-breaker isn't worth it.

## Options considered
1. **Pi QDevice now, removed when the third node joins:** automatic quorum in the meantime; extra setup, root SSH to the Pi, one more thing to monitor, and thrown away later.
2. **Two nodes, no QDevice, manual fix:** nothing extra to build; while a node is down, the other can't change VMs until someone runs `pvecm expected 1`.
3. **Wait with playbooks 02 and 03 until the third node arrives:** clean, but stalls the roadmap for an unknown time.

## Decision
Option 2, chosen by Shawn on 2026-10-27. No Proxmox HA (it would fence the survivor). A runbook covers the node-down case (`pvecm expected 1`, only when the other node is really off). k3s starts now on two VMs of 4.5 GB: a server with embedded etcd on `pve01`, an agent on `pve02`. The Raspberry Pi 3s run Uptime Kuma. Langfuse stays on Langfuse Cloud (ADR-0012).

## Consequences
- Playbooks 02 and 03 go ahead now on about 9 GB for k3s; Backstage fits, tightly.
- A node outage needs a person to restore control of VMs on the other node; running VMs aren't affected.
- Losing `pve01` also stops the k3s control plane until it's back; apps on `k3s-02` keep running.
- The third node is a join, not a rebuild ([add a node](../domains/proxmox/howto-add-node.md)): it makes quorum automatic, and k3s becomes three servers by adding `k3s-03` and rebuilding `k3s-02` as a server. This ADR is then superseded.

## In a team or enterprise setting
Never run a two-node production cluster without a witness (QDevice, quorum disk or cloud witness). A lab can accept a documented manual step to save effort, as long as the failure mode is written down and drilled before it happens.
