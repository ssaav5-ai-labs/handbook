---
type: adr
title: Give agents read access through upstream MCP servers run as sidecars, each holding only its own credential
description: The SRE crews read the cluster through kubernetes-mcp-server (read-only, Hermes' reader role) and Grafana Cloud through mcp-grafana (writes disabled, Viewer service account); each runs as a loopback-only sidecar with its own credential, and the crews' container holds neither.
domain: ai-stack
tags: [mcp, kubernetes, grafana-cloud, rbac, security, agents, sidecars]
status: accepted
created: 2026-11-04
updated: 2026-11-13
visibility: public
reuse: portable
related: [0021-grafana-cloud-for-monitoring.md, 0023-hermes-on-k3s-pod-as-sandbox.md, 0027-crewai-crews-as-mcp-tools.md, 0029-agent-writes-only-through-an-approval-gated-mcp-server.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0028. Give agents read access through upstream MCP servers run as sidecars, each holding only its own credential

## Context
The crews (ADR-0027) need to read the cluster (pods, events, logs, resource use) and Grafana Cloud (metrics and logs over days, alert rules). ADR-0021 left open how agents read metrics and logs: "a scoped Grafana Cloud read token behind an MCP server, never in a transcript". Hermes reads the cluster with `kubectl` in its own container, which works but means every credential sits next to the agent's shell (ADR-0023, Consequences).

Checked on 2026-11-04: `kubernetes-mcp-server` v0.1.1 (Go, TOML config) has a `read_only` mode that only exposes read-annotated tools, denied resource kinds, and memory bounds per call; `mcp-grafana` v2.2.0 (Go) has `--disable-write`, a category allow-list, streamable HTTP, and binds to loopback without needing a caller token.

## Options considered
1. **Write our own small MCP servers**: exactly the tools wanted, but code to maintain, review and secure, for problems others have solved.
2. **Upstream servers as their own Deployments**: clean separation, but two more pods, Services, NetworkPolicies and caller tokens.
3. **Upstream servers as sidecars in the crews' pod, on loopback**: one pod; each sidecar holds one credential; only the crews container can reach them.
4. **Credentials in the crews' container, tools as Python functions**: the fewest moving parts, and the weakest boundary: the agent's process holds everything.

## Decision
Option 3:
- **Kubernetes:** `kubernetes-mcp-server`, `read_only`, `core` toolset, Secrets and ConfigMaps denied, small memory bounds, on `127.0.0.1:8002`. The pod's ServiceAccount token isn't mounted automatically; a projected token is mounted into this sidecar only. The ServiceAccount is bound to Hermes' `hermes-reader` ClusterRole (get, list, watch; no Secrets, ConfigMaps or exec).
- **Grafana:** `mcp-grafana` with `--disable-write` and only the query and read categories, on `127.0.0.1:8001`, with a token for a dedicated `sre-crews-reader` service account with the **Viewer** role, in this sidecar's environment only.
- The crews' container gets its gateway key and the bearer token Hermes presents, by key, not the whole Secret. The crews additionally filter each server's tools to a static list.
- All images pinned by digest; versions in `bootstrap/versions.env`.

## Consequences
- Two independent read-only layers: the server's own mode and a credential that can't write. A bug or a prompt injection in the crews can at most read what Hermes can already read.
- Containers in a pod share the network, so the crews container could reach the internet the sidecars need (Grafana Cloud, GitHub for git-sync). The NetworkPolicy still keeps the pod off the LAN.
- Upstream tool names and flags change between releases; a rename breaks the static filters loudly (the crews log missing tools), not silently.
- The Grafana token can query all of the stack's data sources, not only the lab's labels. It's a free stack used only by the lab, so that's acceptable; a shared stack would need data source permissions.
- The same sidecars can serve other agents later (OpenCode, the AI factory) by adding a front door with TLS and a caller token.

## In a team or enterprise setting
Give each agent capability its own identity and run it as close to the agent as possible, with the narrowest credential and the server's own read-only switch on top. Prefer vendor-maintained MCP servers (Grafana's, the Kubernetes community's) to home-grown ones, pin them, and review their tool lists like you'd review a dependency's permissions.
