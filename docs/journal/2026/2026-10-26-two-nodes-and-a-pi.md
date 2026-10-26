---
type: journal
title: Two Proxmox nodes and a Raspberry Pi
description: The spare laptop meant as a third node broke and the old nodes take no more RAM, so the cluster stays at two nodes with a Pi as the tie-breaker vote.
domain: proxmox
tags: [hardware, cluster, qdevice, capacity]
status: active
created: 2026-10-26
updated: 2026-10-26
visibility: public
reuse: lab-specific
related: [../../domains/proxmox/reference-hardware.md, ../../../playbooks/02-proxmox/PLAYBOOK.md]
blog: candidate
---

# 2026-10-26: Two Proxmox nodes and a Raspberry Pi

## What happened
- Opened `pve01`: one SODIMM slot, already holding 8 GB DDR3L. The firmware reported four slots; it was wrong. `pve02` has the same board. Neither can grow.
- The spare laptop planned as `pve03` broke before it joined the cluster.

## Decision
Stay at two nodes and add a Raspberry Pi 3 as a QDevice, so the cluster keeps quorum with either node down. k3s gets a server VM on `pve01` and an agent on `pve02`, about 4.5 GB each. The rough budget for everything through Backstage is 6-6.5 GB, so it fits, tightly.

## What I'd do differently
Check RAM slots by opening the case, not with `dmidecode`, on boards whose firmware says "To be filled by O.E.M.".

## Next
Buy a used 32 GB mini PC only when Grafana shows the cluster running out of memory. It joins as `pve03` and replaces the QDevice.
