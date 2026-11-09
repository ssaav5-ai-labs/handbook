---
type: adr
title: Run Hermes on k3s from Git, with the pod as its sandbox and policy in a read-only managed config
description: Hermes Agent runs as one pod deployed by Argo CD, executes commands in its own container, reads the cluster through a read-only ServiceAccount, is kept off the home LAN by a NetworkPolicy, takes model, approval and skill policy from a ConfigMap it can't change, and reads reviewed skills from the homelab-agents repo.
domain: ai-stack
tags: [hermes, agents, k3s, argocd, rbac, networkpolicy, security, skills]
status: accepted
created: 2026-11-01
updated: 2026-11-08
visibility: public
reuse: portable
related: [0008-vendor-neutral-ai-stack.md, 0009-hermes-for-local-automation.md, 0020-secrets-in-git-with-sops-age-ksops.md, 0022-llm-gateway-on-k3s.md, 0024-alerts-to-hermes-by-polling-then-in-cluster-webhook.md, 0025-gateway-virtual-keys-with-postgres.md]
supersedes: [0009-hermes-for-local-automation.md]
superseded_by: []
blog: candidate
---

# 0023. Run Hermes on k3s from Git, with the pod as its sandbox and policy in a read-only managed config

## Context
ADR-0009 chose Hermes Agent for agentic automation with guardrails: containerized, the **Docker terminal backend**, approvals on, scoped read-only credentials, model calls through the gateway, skills reviewed in Git, versions pinned. It assumed Hermes would run next to a Docker daemon. The laptop has no room for it (8 GB, one dev container at a time), and the lab's always-on compute is k3s, where a pod has no Docker socket. Mounting the node's container runtime into an agent's pod would give it the node.

Hermes is now meant to be the lab's front door: chat from the phone through Slack, and a first diagnosis for every Grafana Cloud alert. Its docs (v0.22.x) describe the official image (`nousresearch/hermes-agent`, state in `/opt/data`, `gateway run` supervised by s6), Slack Socket Mode, a built-in signed webhook receiver, approval modes with an unattended "deny", and a **managed scope**: a config layer in a directory the agent can't write that wins over its own `config.yaml`.

## Options considered
1. **Docker-in-Docker sidecar** for the Docker backend: a privileged sidecar, more memory, and a privileged container is a worse sandbox than the one it replaces.
2. **SSH backend to a separate VM**: real isolation, but another VM on 8 GB nodes, and the agent's useful work (reading the cluster) would need credentials on that VM anyway.
3. **Local backend inside the pod, with Kubernetes as the sandbox**: commands run in Hermes' own container; what they can reach is set by the ServiceAccount, a NetworkPolicy, the container's security context and the memory limit.
4. **Hermes on the laptop**: no room, and off whenever the laptop sleeps.

## Decision
Option 3, deployed by Argo CD from `homelab-gitops` (`platform/hermes`, AppProject `agents`), the upstream image pinned by digest:
- **Cluster access:** a ServiceAccount with `get`/`list`/`watch` on workloads, events, logs, nodes, Argo CD applications and monitoring CRDs; **no** Secrets, ConfigMaps, `exec`, `port-forward` or write verbs. Changes are proposed to the human, never made.
- **Network:** default deny; egress to DNS, the gateway, the API server and the internet (HTTPS/HTTP), with all private ranges excluded, so not Proxmox, the router or other LAN hosts. Ingress only to the webhook port, only from the `monitoring` namespace, for an in-lab alert manager later (ADR-0024); nothing outside the cluster can reach Hermes.
- **Container:** no privilege escalation, capabilities dropped except what the image's startup needs to fix volume ownership and drop to its user, RuntimeDefault seccomp, memory limit; Pod Security `baseline` for the namespace.
- **Policy from Git:** model and provider (the gateway, with Hermes' own virtual key, ADR-0025), side tasks on `fast`, disabled toolsets (browser and other heavy or outward tools), `approvals.mode: manual`, unattended and cron sessions deny dangerous commands, an empty command allowlist so "always approve" can't persist, deny rules for cluster writes and `git push`, skill write approval, secret redaction, and the webhook routes all live in the managed scope (a ConfigMap mounted read-only, located by an env var set in the pod spec).
- **Skills:** reviewed skills come from the new repo `homelab-agents` (`hermes-skills/`) through a git-sync sidecar into a read-only mount; skills Hermes writes are staged for approval and promoted by PR.
- **State:** sessions and memory on a 5 Gi `local-path` volume, treated as a cache (no backup); the persona (`SOUL.md`) is copied from Git at every start.
- **Off:** the dashboard and the OpenAI-compatible API server. Hermes opens no inbound path: Slack (Socket Mode) and the alert poller only connect out.

## Consequences
- Hermes runs where the lab runs, always on, with no Docker socket and no LAN reach; the guardrails are Kubernetes objects in Git that a reviewer can read.
- Hermes and its commands share one container, so a command can read what Hermes' process can: its gateway key, Slack tokens and webhook secret. Hermes strips known credentials from its subprocesses, but that isn't a boundary. The mitigation is what those credentials can do: a capped, revocable gateway key; a bot token for one workspace; a webhook secret that only lets someone trigger a read-only diagnosis.
- The `local-path` volume ties Hermes to one node: if that node is down, Hermes is down too. The plain Slack alert and `LabSilent` come from Grafana Cloud and keep working; Hermes is the bonus, not the alert path.
- Hermes' image is large (about 1.1 GB compressed) and needs about 768 Mi to 1 Gi of memory: the largest single workload on the 8 GB nodes so far. Revisit if a third node arrives or if memory is tight in playbook 07.
- Anything changed through chat that touches policy (model, approvals) is either refused (managed) or lost on restart; the fix is a PR. That's the point, and occasionally a nuisance.
- Read-only means Hermes can't fix anything itself. Write access, if it ever comes, should be narrow (one namespace, one verb), behind approvals, and its own ADR.

## In a team or enterprise setting
The same pattern scales: an agent per team in its own namespace, a ServiceAccount from a reviewed role, egress through an allow-list proxy, policy from a central managed config the agent can't override, skills in a reviewed repository, and per-agent model keys with budgets. The step most teams skip is the one that matters: deciding what the agent may **not** do, and enforcing it below the agent (RBAC, network), not in its prompt.
