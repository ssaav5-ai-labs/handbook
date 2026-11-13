---
type: reference
title: Open questions
description: Decisions not yet made, with current leaning; each closes with an ADR.
domain: meta
status: active
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-11-13
---

# Open questions

| Question | Domain | Leaning | Decided in |
|---|---|---|---|
| Custom domain for the site | github | Later; use `ssaav5-ai-labs.github.io/handbook` for now | Playbook 01 |
| Primary handbook editor | workstation | OpenKnowledge for handbook, Obsidian for career vault | Playbook 00, step 6 |
| Models behind each gateway alias | ai-stack | Cheapest that fits, checked against current OpenRouter prices | Playbook 00, step 4 |
| Where Hermes runs | ai-stack | On k3s as its own pod (no Docker socket); the laptop has no room (8 GB) | [ADR-0023](../decisions/0023-hermes-on-k3s-pod-as-sandbox.md) (accepted) |
| Virtual key for OpenCode | ai-stack | Move OpenCode to its own virtual key once the gateway has TLS; it keeps the master key until then | Playbook 06 |
| Default coding harness | ai-stack | OpenCode (any model); Claude Code optional | Playbook 00 |
| SRE agent framework: CrewAI vs LangGraph | ai-stack | CrewAI, with tools as MCP servers so it stays swappable | Playbook 07 |
| Uses for the Raspberry Pi 3s | proxmox | Uptime Kuma for outside-the-cluster checks; DNS later. No QDevice (ADR-0013) | After playbook 05 |
| AI factory architecture | ai-factory | | After platform is up |
| Proxmox provisioning | proxmox | OpenTofu (bpg/proxmox) + cloud-init template | [ADR-0014](../decisions/0014-provision-proxmox-vms-opentofu-bpg-provider.md) |
| k3s topology (nodes, HA, storage) | k3s | Three servers with embedded etcd behind kube-vip, heavy apps on `k3s-03`; local-path storage | [ADR-0015](../decisions/0015-k3s-embedded-etcd-server-and-agent.md), [ADR-0031](../decisions/0031-k3s-three-servers-behind-kube-vip.md) (proposed) |
| GitOps controller | platform | Argo CD, slim and self-managed, app-of-apps from `homelab-gitops` | [ADR-0019](../decisions/0019-gitops-with-argo-cd-app-of-apps.md) (accepted) |
| Secrets management | platform | SOPS + age in Git, KSOPS in Argo CD; age key in the password manager | [ADR-0020](../decisions/0020-secrets-in-git-with-sops-age-ksops.md) (accepted) |
| Move `homelab-infra/.env` (k3s token) into SOPS | platform | Yes, with the lab age key | Playbook 05, Part B |
| TLS for lab services on the LAN (the gateway is plain HTTP) | platform | A lab CA with cert-manager, trusted on Windows and in dev containers, together with lab DNS on a Pi | With the DNS question |
| Private access to the lab's web UIs from the phone when away | platform | Tailscale with the Kubernetes operator, nothing public; Grafana is already reachable in the cloud | Playbook 06 |
| Gateway virtual keys and spend database | ai-stack | One virtual key per client with its own budget; a small Postgres on k3s | Playbook 06 (Hermes is the second client) |
| k3s control-plane metrics (scheduler, controller manager, etcd) | k3s | Off for now; expose with k3s server flags if a problem needs them (mind the 10k-series budget) | When needed |
| Self-manage CoreDNS with anti-affinity (k3s re-creates it with 1 replica on restart; `install.sh` re-scales it) | k3s | Later; `install.sh` re-scales the embedded CoreDNS to 2 replicas for now (not anti-affined, so it could co-locate) | |
| Grafana Cloud contact points, policies and dashboards as code | platform | Terraform `grafana` provider in `homelab-infra`, once there's more than a handful; alert rules are already code via CI ([ADR-0026](../decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)) | When the UI setup grows |
| How the SRE agents read metrics and logs | ai-stack | A scoped Grafana Cloud read token behind an MCP server, never in a transcript | Playbook 07 |
| Observability stack | platform | Grafana Cloud free tier through Alloy (`k8s-monitoring` chart); rules in Git imported by CI into Grafana-managed rules; alerts to Slack. Self-hosted VictoriaMetrics when a third node arrives | [ADR-0021](../decisions/0021-grafana-cloud-for-monitoring.md) (accepted, amended by [ADR-0026](../decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)), playbook 05 |
| Site generator after MkDocs Material's maintenance ends (Nov 5, 2026) | meta | Stay on MkDocs 1.6.1 (pinned); evaluate Zensical | Zensical blog/plugin parity |
| Third Proxmox node | proxmox | `pve03`, i7-12700T, 32 GB, joined 2026-11-07 | [ADR-0030](../decisions/0030-three-node-proxmox-cluster.md) |
| What to do with pve03's spare ~17 GB | proxmox | Keep free until Backstage (playbook 08) is sized; candidates: grow `k3s-03`, self-host Langfuse (ADR-0012) or VictoriaMetrics (ADR-0021) | After playbook 08 |
| The crew's k8s-mcp can't read `applications.argoproj.io` — no way to check Argo CD app health from within a crew | ai-stack | | |
| Hermes' fallback when `investigate_alert` errors is untested — drill 5a's self-heal was too fast to catch the crew-down window | ai-stack | | |
| Drill 6 (budget) is untested — walked through the scenario but never fired a real budget exhaustion | ai-stack | | |
