---
type: journal
title: Hardware inventory reshapes the roadmap
description: An 8 GB laptop and an 8 GB Proxmox host decide what runs where; Proxmox moves up, Hermes moves to k3s, Langfuse goes to the cloud for now.
domain: proxmox
tags: [hardware, capacity, roadmap, langfuse]
status: active
created: 2026-10-23
updated: 2026-10-23
visibility: public
reuse: lab-specific
blog: candidate
---

# 2026-10-23: Hardware inventory reshapes the roadmap

## Goal
Before running Hermes and Langfuse on the laptop (old playbook 02), check whether the hardware can carry them.

## What I found
- Laptop: 8 GB RAM. Proxmox host `pve01`: 8 GB RAM (about 5.8 GB free), 2 cores / 4 threads, 256 GB SSD, 1 TB USB disk, no VMs yet. Details in [lab hardware](../../domains/proxmox/reference-hardware.md).
- Self-hosted Langfuse needs about 4 GB on its own. Neither machine can spare that next to everything else.

## Decisions made
- The laptop is a thin client. Always-on and heavy workloads go to Proxmox.
- New order: 02 Proxmox, 03 k3s (single node), 04 Argo CD, 05 monitoring plus moving the gateway, 06 Hermes on k3s, 07 CrewAI, 08 AI factory.
- [ADR-0012](../../decisions/0012-langfuse-cloud-until-capacity.md): Langfuse Cloud (EU, free tier) until the lab can host it; ADR-0010 stays the target.

## Lessons
- Inventory hardware before designing workloads. The first draft assumed a laptop could host six extra containers.
- Sizing constraints are portfolio material too: a small lab that states its limits is more credible than a large one that hides them.

## Next
- Playbook 02: Proxmox host and the k3s VM.
