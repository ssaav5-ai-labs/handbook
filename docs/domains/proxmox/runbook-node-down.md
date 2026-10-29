---
type: runbook
title: Recover control when a Proxmox node is down
description: Two-node cluster without a QDevice: how to keep managing VMs when one node is offline, and what not to do.
domain: proxmox
tags: [proxmox, quorum, cluster]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-28
updated: 2026-10-28
related: [reference-proxmox.md, ../../decisions/0013-two-nodes-without-qdevice.md]
blog: none
---

# Recover control when a Proxmox node is down

## Why this matters

`pveCluster01` has two nodes and no QDevice ([ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md)). Each node has one vote; a majority is 2. When one node is down, the survivor loses quorum: running VMs keep running, but `/etc/pve` turns read-only, so you can't start, stop, create, or change VMs.

## Rules

- Reboot one node at a time and wait for it to turn green before touching the other.
- No Proxmox HA (Datacenter → HA stays empty): without quorum, HA would fence (reboot) the surviving node.
- Don't edit `corosync.conf` for `two_node` mode; it isn't a supported Proxmox setup.

## When a node is down

On the **surviving** node, in the host shell:

```bash
pvecm expected 1
```

This lowers the expected votes to 1. The survivor regains quorum and can manage VMs again. corosync goes back to 2 expected votes on its own when the other node rejoins.

**Only use this when the other node is really off.** Never run it while both nodes are running but can't see each other — both sides could change the same VM independently, corrupting it.

## Verify

```bash
pvecm status | grep -i quorate
# Must print: Quorate: Yes
```

## Undo

Start the other node. `pvecm status` should show `Expected votes: 2` automatically. If not: `pvecm expected 2`.