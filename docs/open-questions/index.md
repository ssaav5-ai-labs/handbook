---
type: reference
title: Open questions
description: Decisions not yet made, with current leaning; each closes with an ADR.
domain: meta
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-20
---

# Open questions

| Question | Domain | Leaning | Decided in |
|---|---|---|---|
| Custom domain for the site | github | Later; use `ssaav5-ai-labs.github.io/handbook` for now | Playbook 01 |
| Primary handbook editor | workstation | OpenKnowledge for handbook, Obsidian for career vault | Playbook 00, step 6 |
| Models behind each gateway alias | ai-stack | Cheapest that fits, checked against current OpenRouter prices | Playbook 00, step 4 |
| Where Hermes runs: its own container in the workstation stack, or the existing WSL install with the Docker terminal backend | ai-stack | Container next to the gateway and Langfuse; WSL install as fallback | Playbook 02 |
| Default coding harness | ai-stack | OpenCode (any model); Claude Code optional | Playbook 00 |
| SRE agent framework: CrewAI vs LangGraph | ai-stack | CrewAI, with tools as MCP servers so it stays swappable | Playbook 07 |
| AI factory architecture | ai-factory | | After platform is up |
| Proxmox provisioning | proxmox | OpenTofu/Terraform (bpg/proxmox) + Packer templates + Ansible | Hardware inventory |
| k3s topology (nodes, HA, storage) | k3s | 3 server nodes, embedded etcd | Hardware inventory |
| GitOps controller | platform | Argo CD (app-of-apps) | Playbook 05 |
| Secrets management | platform | SOPS + age | Playbook 03 |
| Observability stack | platform | kube-prometheus-stack + Loki + Grafana | Playbook 06 |
| Site generator after MkDocs Material's maintenance ends (Nov 5, 2026) | meta | Stay on MkDocs 1.6.1 (pinned); evaluate Zensical | Zensical blog/plugin parity |
