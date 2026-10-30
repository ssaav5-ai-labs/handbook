---
type: reference
title: Playbook catalog
description: Every AI-first setup playbook across the lab's repos, in the order they run.
domain: meta
status: active
visibility: public
reuse: portable
created: 2026-10-20
updated: 2026-10-29
---

# Playbook catalog

Each playbook is a few manual steps plus one prompt. See [how the agent runs them](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/RUNNING.md).

| # | Playbook | Repo | Depends on | Status |
|---|---|---|---|---|
| 00 | [Workstation + knowledge capture](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/00-workstation-knowledge/PLAYBOOK.md) | handbook, workstation | none | done 2026-10-22 |
| 01 | [GitHub organization + publish handbook](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/01-github-foundation/PLAYBOOK.md) | handbook | 00 | done 2026-10-23 |
| 02 | [Two-node Proxmox cluster and the k3s VMs](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/02-proxmox/PLAYBOOK.md) | homelab-infra | 01 | done |
| 03 | [k3s cluster: server + agent, zram; three servers when a third node joins](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/03-k3s/PLAYBOOK.md) | homelab-infra | 02 | done 2026-10-29 |
| 04 | [Argo CD from Git (app-of-apps), secrets with SOPS + age](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/04-argocd/PLAYBOOK.md) | homelab-gitops | 03 | done 2026-10-29 |
| 05 | Monitoring; move the gateway to the cluster; traces to Langfuse Cloud | homelab-gitops | 04 | planned |
| 06 | Hermes on k3s (sandboxed) | homelab-gitops | 05 | planned |
| 07 | SRE management agents (CrewAI over MCP tools) | ai-factory | 05 | planned |
| 08 | AI dev factory | ai-factory | 05 | planned |
