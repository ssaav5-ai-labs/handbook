---
type: reference
title: Open questions
description: Decisions not yet made, with current leaning; each closes with an ADR.
domain: meta
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-27
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
| Uses for the Raspberry Pi 3s | proxmox | Uptime Kuma for outside-the-cluster checks; DNS later. No QDevice (ADR-0013) | After playbook 05 |
| AI factory architecture | ai-factory | | After platform is up |
| Proxmox provisioning | proxmox | OpenTofu (bpg/proxmox) + a cloud-init template per node; no Packer or Ansible yet | Playbook 02 |
| k3s topology (nodes, HA, storage) | k3s | Server (embedded etcd) on `pve01`, agent on `pve02`; three servers when a third node joins ([lab hardware](../domains/proxmox/reference-hardware.md)) | Playbook 03 |
| GitOps controller | platform | Argo CD (app-of-apps), core components only | Playbook 04 |
| Secrets management | platform | SOPS + age | Playbook 03-04 |
| Observability stack | platform | VictoriaMetrics + Grafana (fits a 5 GB node); kube-prometheus-stack when there is room | Playbook 05 |
| Site generator after MkDocs Material's maintenance ends (Nov 5, 2026) | meta | Stay on MkDocs 1.6.1 (pinned); evaluate Zensical | Zensical blog/plugin parity |
| Third Proxmox node | proxmox | 16 GB or more, wired Ethernet; Chromebox (16 GB) among the candidates ([add a node](../domains/proxmox/howto-add-node.md)) | When Shawn picks one |
