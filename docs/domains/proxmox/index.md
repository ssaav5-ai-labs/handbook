---
type: explanation
title: Proxmox
description: Overview of the proxmox domain - what exists, how it fits, links to how-tos, runbooks and decisions.
domain: proxmox
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-27
---

# Proxmox

A two-node Proxmox VE cluster, `pveCluster01` (`pve01`, `pve02`), runs the lab, without a tie-breaker until a third node joins ([ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md), [add a node](howto-add-node.md)). See [lab hardware](reference-hardware.md) for specs and what fits, and [playbook 02](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/02-proxmox/PLAYBOOK.md) for how it is set up.
