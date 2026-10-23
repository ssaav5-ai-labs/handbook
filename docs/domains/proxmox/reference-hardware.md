---
type: reference
title: Lab hardware
description: The machines in the lab, what each one runs, and the limits that shape every playbook.
domain: proxmox
tags: [hardware, capacity, proxmox, k3s]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-10-23
related: [index.md, ../../decisions/0012-langfuse-cloud-until-capacity.md]
blog: candidate
---

# Lab hardware

Inventory taken 2026-10-23. Addresses and serial numbers stay out of this public page.

| Machine | CPU | RAM | Storage | Network | Role |
|---|---|---|---|---|---|
| Laptop (Windows) | Intel i3-1215U | 8 GB | 238 GB SSD | Wi-Fi | Thin client: editors, one dev container at a time, OpenCode. Hosts the LLM gateway until it moves to k3s. |
| `pve01` (Proxmox VE 9.2) | Intel i5-4302Y, 2 cores / 4 threads | 8 GB (~5.8 GB free idle) | 256 GB SATA SSD (`local`, `local-lvm`); 1 TB USB HDD | 1 GbE (`vmbr0`, VLAN 100 defined) | One k3s VM. USB disk for backups only. |
| Spare laptops (2) | not yet inventoried | | | | Candidate second node. |
| Raspberry Pi 3 (2) | ARM Cortex-A53 | 1 GB each | SD / USB | 100 Mb Ethernet | Candidates for outside-the-cluster uptime checks and DNS. |

## What fits
- **k3s:** one VM on `pve01` with 4 vCPU, 5 GB RAM, 80 GB disk. Single node: no HA, which is stated rather than hidden.
- **On the cluster:** Argo CD (core components), light monitoring (VictoriaMetrics + Grafana rather than the full Prometheus stack), the LLM gateway, Hermes, CrewAI agents.
- **Does not fit:** self-hosted Langfuse (~4 GB). Traces go to Langfuse Cloud for now (ADR-0012).

## Upgrade path
The biggest single lever is a used business mini PC with 32 GB RAM (Lenovo M720q/M920q, HP EliteDesk 800 mini class) as a second Proxmox node: multi-node k3s and self-hosted Langfuse become possible. Spare laptops are the free alternative if they have 16 GB or can take it.
