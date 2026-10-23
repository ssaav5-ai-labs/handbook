---
type: reference
title: Playbook catalog
description: Every AI-first setup playbook across the lab's repos, in the order they run.
domain: meta
status: active
visibility: public
reuse: portable
created: 2026-10-20
updated: 2026-10-23
---

# Playbook catalog

Each playbook is a few manual steps plus one prompt. See [how the agent runs them](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/RUNNING.md).

| # | Playbook | Repo | Depends on | Status |
|---|---|---|---|---|
| 00 | [Workstation + knowledge capture](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/00-workstation-knowledge/PLAYBOOK.md) | handbook, workstation | none | done 2026-10-22 |
| 01 | [GitHub organization + publish handbook](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/01-github-foundation/PLAYBOOK.md) | handbook | 00 | done 2026-10-23 |
| 02 | Local AI automation (Hermes, sandboxed) + local Langfuse | workstation | 00 | planned |
| 03 | Proxmox host and VM templates | homelab-infra | 01 | planned |
| 04 | k3s cluster | homelab-infra | 03 | planned |
| 05 | Argo CD (app-of-apps) | homelab-gitops | 04 | planned |
| 06 | Observability; move gateway + Langfuse to the cluster | homelab-gitops | 05 | planned |
| 07 | SRE management agents (CrewAI over MCP tools) | ai-factory | 06 | planned |
| 08 | AI dev factory | ai-factory | 06 | planned |
