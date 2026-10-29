---
type: reference
title: Decision log
description: Index of all architecture decision records and their status.
domain: meta
status: active
visibility: public
reuse: portable
created: 2026-10-20
updated: 2026-10-29
---

# Decision log

| # | Decision | Domain | Status |
|---|---|---|---|
| [0001](0001-record-decisions-as-adrs.md) | Record decisions as ADRs | meta | accepted |
| [0002](0002-markdown-in-git-as-system-of-record.md) | Markdown + frontmatter in Git as system of record | meta | accepted |
| [0003](0003-central-handbook-repo.md) | One central handbook repo | meta | accepted |
| [0004](0004-github-free-org-public-repos.md) | Free GitHub org, public repos | github | accepted |
| [0005](0005-private-career-vault.md) | Private career vault | meta | accepted |
| [0006](0006-local-repo-layout.md) | Local layout `~/code/<host>/<owner>/<repo>` | workstation | accepted |
| [0007](0007-ai-first-playbooks.md) | AI-first playbooks instead of command-list tutorials | meta | accepted |
| [0008](0008-vendor-neutral-ai-stack.md) | Open interfaces + self-hosted LLM gateway (OpenRouter upstream) | ai-stack | accepted |
| [0009](0009-hermes-for-local-automation.md) | Hermes Agent for local automations, sandboxed | ai-stack | proposed |
| [0010](0010-langfuse-for-tracing-and-evals.md) | Self-hosted Langfuse for tracing and evals | ai-stack | accepted |
| [0011](0011-github-org-name.md) | Single GitHub org `ssaav5-ai-labs` | github | accepted |
| [0012](0012-langfuse-cloud-until-capacity.md) | Langfuse Cloud (EU, free tier) until the lab can host Langfuse | ai-stack | accepted |
| [0013](0013-two-nodes-without-qdevice.md) | Two Proxmox nodes without a QDevice until a third node is chosen | proxmox | accepted |
| [0014](0014-provision-proxmox-vms-opentofu-bpg-provider.md) | Provision Proxmox VMs with OpenTofu (bpg/proxmox) and a cloud-init template | proxmox | proposed |
| [0015](0015-k3s-embedded-etcd-server-and-agent.md) | k3s with embedded etcd: one server and one agent, pinned install scripts | k3s | accepted |
| [0016](0016-zram-swap-on-k3s-nodes.md) | zram swap plus a small swap file on k3s nodes, `LimitedSwap` for pods | k3s | accepted |
| [0017](0017-kubeconfig-on-windows-mounted-into-containers.md) | Kubeconfig on Windows mounted into dev containers; SSH key in a Docker volume | workstation | accepted |
| [0019](0019-gitops-with-argo-cd-app-of-apps.md) | Slim, self-managed Argo CD with app-of-apps, from `homelab-gitops` | platform | proposed |
| [0020](0020-secrets-in-git-with-sops-age-ksops.md) | Secrets in Git with SOPS + age, decrypted by KSOPS in Argo CD | platform | proposed |
