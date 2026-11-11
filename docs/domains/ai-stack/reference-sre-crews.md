---
type: reference
title: SRE crews reference
description: The CrewAI-based SRE crews (investigate_alert, weekly_capacity_report) running on k3s, their models, limits, image, and read-only abilities.
domain: ai-stack
tags: [crewai, mcp, agents, sre, hermes, kubernetes, grafana-cloud]
status: draft
visibility: public
reuse: portable
created: 2026-11-09
updated: 2026-11-10
related: [index.md, reference-gateway.md, reference-hermes.md, ../../decisions/0027-crewai-crews-as-mcp-tools.md, ../../decisions/0028-agent-read-access-through-upstream-mcp-sidecars.md, ../../decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md]
blog: candidate
---

# SRE crews reference

Two small CrewAI crews run on the cluster, written in the `homelab-agents` repo and deployed by Argo CD from `homelab-gitops`. They are tools on an MCP server that Hermes calls; the crews never talk to you directly.

## Versions (pinned 2026-11-09)

| Component | Version | Why |
|---|---|---|
| crewai | 1.15.39 | newest; Python 3.10–3.13; no extras (the `litellm` extra pulls a second LiteLLM copy) |
| mcp (SDK) | 1.30.0 | newest 1.x; CrewAI 1.15 requires `mcp<2,>=1.30.0`; same SDK for the crews' own MCP server |
| kubernetes-mcp-server | v0.1.2 | `quay.io/containers/kubernetes_mcp_server`, read-only |
| mcp-grafana | v2.2.0 | `grafana/mcp-grafana`, `--disable-write` |
| base image | python:3.13-slim | by digest |

## Keeping CrewAI quiet

Environment variables set on the crews container (and the spike):

```
CREWAI_DISABLE_TELEMETRY=true
CREWAI_TRACING_ENABLED=false
ANONYMIZED_TELEMETRY=False
```

Verified 2026-11-09: a run with `HTTPS_PROXY=http://127.0.0.1:9` (dead proxy) still succeeded, so CrewAI and its dependencies send nothing to their own servers.

## The crews

### investigate_alert
Three agents in a row (`Process.sequential`), `memory=False`, `max_rpm=20`, every agent `max_iter=6`, `allow_delegation=False`, crew `max_execution_time=240`:

1. **Triager** (`fast`, no tools) — reads the alert, lists at most five checks.
2. **Investigator** (`code`, Kubernetes + Grafana MCP + `find_runbook`) — runs the checks, quotes what it saw.
3. **Scribe** (`fast`, no tools) — writes the report in playbook 06 `alert-triage` format.

### weekly_capacity_report
Deterministic, not an agent: the tool fetches pods and 7-day peaks through a direct loopback MCP client, computes the table in Python, and the LLM (`code`) writes only the one-line verdict. Proposes right-sizing by the playbook 05 step 9 rule (limit ≥ 2× request and ≥ peak + 128 Mi). On any fetch failure it returns `capacity report unavailable: <which>` and no table. Proposes only.

## Limits

- One crew run at a time; a second concurrent call returns "busy" immediately.
- Request timeout 60s per model call; crew max 240s.
- The crews' gateway key budget and RPM are in `reference-gateway.md`.

## Memory (spike, 2026-11-09)

- Peak RSS 265 Mi for a one-agent run → crews container request **384 Mi** (265 × 1.25 rounded up).
- Import ~18.2s.

## Image and deployment

- Image built by CI in `homelab-agents` (workflow `image.yml`), tagged `ghcr.io/ssaav5-ai-labs/sre-crews:sha-<short>`, public, pinned by digest in `homelab-gitops`.
- First image: `ghcr.io/ssaav5-ai-labs/sre-crews:sha-1085cd0@sha256:25044f0d8e66eb60f2b570bc742d9af25b54729b172b5e472bfdfbb77b2b23e9` (built 2026-11-09), public, 631.4 MiB compressed (9 layers).
- Second image: `ghcr.io/ssaav5-ai-labs/sre-crews:sha-c3bc01f@sha256:70076cb2ce73ebb001d7f4690d8e3501e632e5752e1c2b3271889283762f9c06` (built 2026-11-10) — fixes the Grafana alerting tool name.
- Third image: `ghcr.io/ssaav5-ai-labs/sre-crews:sha-62da16d@sha256:03b2931bd9c5f3fc3535582c1635971aca19628f7b26dba18de8821cf7683c89` (built 2026-11-10) — the tool handlers `await crew.kickoff_async()` so FastMCP can call them from inside its event loop.
- New version reaches the cluster: merge → `image.yml` → digest → PR in `homelab-gitops`.

### Tool names (mcp-grafana v2.2.0)

The static tool filter in `tools.py` must match v2.2.0's names: `query_prometheus`, `query_loki_logs`, `list_datasources`, `alerting_rules_read` (the older `list_alert_rules` was renamed; the first image used the old name and the filter was fixed in the second build).

## The pod (`sre-crews`, namespace `sre`, PR #60)

Four containers share the pod's network but not its credentials (ADR-0028):

| Container | Credentials it holds | Read-only controls |
|---|---|---|
| `crews` | `CREWS_GATEWAY_KEY`, `CREWS_MCP_TOKEN` (the bearer Hermes presents) | nothing that can write |
| `k8s-mcp` | short-lived projected SA token (3600s), mounted in this container only | `read_only = true`, `toolsets = ["core"]`, Secrets + ConfigMaps denied |
| `grafana-mcp` | `GRAFANA_SERVICE_ACCOUNT_TOKEN` | `--disable-write --enabled-tools datasource,prometheus,loki,alerting` |
| `git-sync` | none | syncs the handbook read-only to `/handbook/current` |

- The ServiceAccount `sre-crews` has `automountServiceAccountToken: false`; the pod mounts no default token.
- Both upstream sidecars bind to `127.0.0.1`, so only the crews container can reach them.
- RBAC: `ClusterRoleBinding sre-crews-reader` → the existing `hermes-reader` ClusterRole (get/list/watch; no Secrets/ConfigMaps/exec).
- NetworkPolicy: default-deny; ingress on 8000 from Hermes only; egress to DNS, the gateway (`litellm` on 4000), the API server, and the internet on 443 (Grafana Cloud, GitHub). No path to `lab-actions`.
- Namespace enforces `pod-security.kubernetes.io/enforce: restricted`; every container `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, capabilities dropped, non-root.
- `k8s-mcp` runs `list_output = "yaml"` (was `table`) so `resources_list` returns full pod specs for the deterministic capacity report. Trade-off: a pod spec's literal `env` `value:` fields now reach the model's context when the investigator reads a pod (`pods_get`/`resources_get` already returned YAML). Secret values are not exposed — they stay `secretKeyRef` references — but plain env values are visible.

## Memory at rest (2026-11-10)

| Container | Request | Limit | At rest |
|---|---|---|---|
| crews | 50m / 384 Mi | 768 Mi | 159 Mi |
| k8s-mcp | 10m / 64 Mi | 192 Mi | 20 Mi |
| grafana-mcp | 10m / 48 Mi | 128 Mi | 17 Mi |
| git-sync | 10m / 32 Mi | 96 Mi | 12 Mi |

## A run, measured (2026-11-10)

The step 6 `investigate_alert` DM (a synthetic `KubePodCrashLooping` in `monitoring`,
a healthy pod):

- DM at 18:33:01 → report at 18:34:32, ~1.5 minutes, correct and in the `alert-triage`
  format (the report said the pod was healthy).
- Cost: the `crews` gateway key spend went `0.0 → 0.066169` USD; Hermes' own key went
  `0.7789 → 0.8026` (+0.024).
- Langfuse traced ~10 crew model calls: 1 triager, 6 investigator, 2 context
  summaries, 1 scribe.

### Follow-ups

- **Langfuse can't separate keys.** Every call shows `default_user_id`, so the per-key
  cost above came from LiteLLM's `/key/list` spend, not Langfuse. To fix, set the
  request user field per client so Langfuse attributes traces to the `crews` vs
  `hermes` key.
- **The investigator hit context summarization** (2 of its calls were context
  summaries). Consider limiting `pods_log` to fewer lines so the investigator's
  evidence-gathering fits in context without summarising.
