---
type: reference
title: Open questions
description: Decisions not yet made, with current leaning; each closes with an ADR.
domain: meta
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-29
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
| Proxmox provisioning | proxmox | OpenTofu (bpg/proxmox) + cloud-init template | [ADR-0014](../decisions/0014-provision-proxmox-vms-opentofu-bpg-provider.md) |
| k3s topology (nodes, HA, storage) | k3s | Server (embedded etcd) on `pve01`, agent on `pve02`, local-path storage; three servers when a third node joins | [ADR-0015](../decisions/0015-k3s-embedded-etcd-server-and-agent.md) |
| GitOps controller | platform | Argo CD, slim and self-managed, app-of-apps from `homelab-gitops` | [ADR-0019](../decisions/0019-gitops-with-argo-cd-app-of-apps.md) (proposed), playbook 04 |
| Secrets management | platform | SOPS + age in Git, KSOPS in Argo CD; age key in the password manager | [ADR-0020](../decisions/0020-secrets-in-git-with-sops-age-ksops.md) (proposed), playbook 04 |
| Move `homelab-infra/.env` (k3s token) into SOPS | platform | Yes, with the lab age key, once playbook 04 is done | After playbook 04 |
| Observability stack | platform | VictoriaMetrics + Grafana (fits a 5 GB node); kube-prometheus-stack when there is room | Playbook 05 |
| Site generator after MkDocs Material's maintenance ends (Nov 5, 2026) | meta | Stay on MkDocs 1.6.1 (pinned); evaluate Zensical | Zensical blog/plugin parity |
| Third Proxmox node | proxmox | 16 GB or more, wired Ethernet; Chromebox (16 GB) among the candidates ([add a node](../domains/proxmox/howto-add-node.md)) | When Shawn picks one |
