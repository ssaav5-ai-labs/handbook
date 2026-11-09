---
type: explanation
title: Proxmox
description: Overview of the proxmox domain - what exists, how it fits, links to how-tos, runbooks and decisions.
domain: proxmox
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-11-07
---

# Proxmox

A three-node Proxmox VE cluster, `pveCluster01` (`pve01`, `pve02`, `pve03`), runs the lab with normal quorum and no Proxmox HA ([ADR-0030](../../decisions/0030-three-node-proxmox-cluster.md)). `pve03` joined on 2026-11-07 ([add a node](howto-add-node.md), [playbook 02b](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/02b-third-node/PLAYBOOK.md)). See [lab hardware](reference-hardware.md) for specs and what fits, [Proxmox configuration](reference-proxmox.md) for storage and backups, and [playbook 02](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/02-proxmox/PLAYBOOK.md) for how the first two nodes were set up.
