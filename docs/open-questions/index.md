---
type: reference
title: Open questions
description: Decisions not yet made, with current leaning; each closes with an ADR.
domain: meta
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-23
---

# Open questions

| Question | Domain | Leaning | Decided in |
|---|---|---|---|
| Custom domain for the site | github | Later; use `ssaav5-ai-labs.github.io/handbook` for now | Playbook 01 |
| Primary handbook editor | workstation | OpenKnowledge for handbook, Obsidian for career vault | Playbook 00, step 6 |
| Models behind each gateway alias | ai-stack | Cheapest that fits, checked against current OpenRouter prices | Playbook 00, step 4 |
| Where Hermes runs | ai-stack | On k3s as its own pod (no Docker socket); the laptop has no room (8 GB) | Playbook 06 |
| Default coding harness | ai-stack | OpenCode (any model); Claude Code optional | Playbook 00 |
| SRE agent framework: CrewAI vs LangGraph | ai-stack | CrewAI, with tools as MCP servers so it stays swappable | Playbook 07 |
| Uses for the spare laptops and Raspberry Pi 3s | proxmox | Laptop with 16 GB+ as a second node; Pis for outside-the-cluster uptime checks and DNS | After inventory |
| AI factory architecture | ai-factory | | After platform is up |
| Proxmox provisioning | proxmox | OpenTofu (bpg/proxmox) + cloud-init template; no Packer or Ansible until there is more than one VM to configure | Playbook 02 |
| k3s topology (nodes, HA, storage) | k3s | One node in one VM on `pve01` (8 GB host); add a node when hardware allows ([lab hardware](../domains/proxmox/reference-hardware.md)) | Playbook 03 |
| GitOps controller | platform | Argo CD (app-of-apps), core components only | Playbook 04 |
| Secrets management | platform | SOPS + age | Playbook 03-04 |
| Observability stack | platform | VictoriaMetrics + Grafana (fits a 5 GB node); kube-prometheus-stack when there is room | Playbook 05 |
| Site generator after MkDocs Material's maintenance ends (Nov 5, 2026) | meta | Stay on MkDocs 1.6.1 (pinned); evaluate Zensical | Zensical blog/plugin parity |
