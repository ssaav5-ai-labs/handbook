---
type: runbook
title: Recover control when Proxmox nodes are down
description: Three-node cluster - one node down needs nothing; two nodes down needs pvecm expected 1 on the survivor, only when the others are really off.
domain: proxmox
tags: [proxmox, quorum, cluster]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-28
updated: 2026-11-07
related: [reference-proxmox.md, ../../decisions/0030-three-node-proxmox-cluster.md, ../../decisions/0013-two-nodes-without-qdevice.md]
blog: none
---

# Recover control when Proxmox nodes are down

## Why this matters

`pveCluster01` has three nodes, one vote each, and needs 2 votes for quorum ([ADR-0030](../../decisions/0030-three-node-proxmox-cluster.md)). Until 2026-11-07 it had two nodes and lost quorum whenever one went down ([ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md), superseded).

Without quorum, running VMs keep running, but `/etc/pve` turns read-only: you can't start, stop, create or change VMs.

## Rules

- Reboot one node at a time and wait for it to turn green before touching the next.
- No Proxmox HA (Datacenter → HA stays empty). VM disks are local, so HA couldn't restart them elsewhere anyway; k3s handles failover.
- Don't add a QDevice. With an odd number of nodes, Proxmox advises against one.

## One node down

Nothing to do. The other two keep quorum (`Quorate: Yes`) and can manage their own VMs. VMs on the down node stay down until it's back; k3s reschedules their pods.

## Two nodes down

On the **surviving** node, in the host shell:

```bash
pvecm expected 1
```

This lowers the expected votes to 1 so the survivor regains quorum. corosync goes back to 3 expected votes on its own as the others rejoin.

**Only use this when the other nodes are really off.** Never run it while nodes are running but can't see each other (for example, a switch problem): two sides could change the same VM independently and corrupt it. Check with the power button or the screen, not the network.

## Verify

```bash
pvecm status | grep -E 'Expected votes|Total votes|Quorate'
# Normal: Expected votes: 3, Total votes: 3, Quorate: Yes
```

## Undo

Start the other nodes. `pvecm status` should show `Expected votes: 3` by itself. If it doesn't: `pvecm expected 3`.
