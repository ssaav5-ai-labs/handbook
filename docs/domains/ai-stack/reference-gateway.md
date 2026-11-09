---
type: reference
title: LLM gateway reference
description: The one endpoint every tool calls - LiteLLM proxy with model aliases in front of OpenRouter, budgets, and key handling.
domain: ai-stack
tags: [litellm, openrouter, gateway, aliases, budget]
status: active
visibility: public
reuse: portable
created: 2026-10-22
updated: 2026-11-08
related: [index.md, ../../decisions/0008-vendor-neutral-ai-stack.md]
blog: none
---

# LLM gateway reference

One endpoint for every agent and harness: a LiteLLM proxy container in front of OpenRouter (ADR-0008). Tools never see vendor model IDs - only aliases.

## Endpoint and keys

| What | Value |
|---|---|
| URL from Windows | `http://localhost:4000` |
| URL from containers | `http://host.docker.internal:4000` (env `LLM_GATEWAY_URL`) |
| URL on the LAN | `http://llm.192.168.86.210.nip.io/v1` (Traefik, HTTP) |
| URL in-cluster | `http://litellm.llm-gateway.svc:4000` |
| Auth | `Authorization: Bearer $LITELLM_MASTER_KEY` (env `LLM_GATEWAY_KEY` in containers) |
| Upstream key | `OPENROUTER_API_KEY`, only in SOPS (`platform/llm-gateway/secret.enc.yaml`) |
| Source of truth | `homelab-gitops` → `platform/llm-gateway/` (config.yaml + secret.enc.yaml) |

The gateway now runs on the cluster (LiteLLM `v1.106.6`, one replica, ~551 Mi) as plain manifests deployed
by Argo CD; the laptop `workstation/gateway/compose.yaml` is the **fallback** for when the cluster is down.
Config lives in Git (`platform/llm-gateway/config.yaml`, no secret), keys live in SOPS
(`secret.enc.yaml`). The master key is a random 32-byte hex value; container-side env vars
(`LLM_GATEWAY_URL`, `LLM_GATEWAY_KEY`) are set with `setx` on the Windows side so every new workspace
inherits them. `/metrics/` is unauthenticated but only reachable in-cluster (the Ingress path is `/v1`).

## Aliases (chosen 2026-10-22)

| Alias | Model | Price per Mtok in/out | Role |
|---|---|---|---|
| `fast` | `z-ai/glm-5.3-flash` | $0.01 / $0.20 | Summaries, journaling, classification |
| `code` | `deepseek/deepseek-v4-pro` | $0.45 / $0.89 | Strong, cost-competitive coding; agent default |
| `reason` | `anthropic/claude-sonnet-5.5` | $2.00 / $10.00 | Frontier planning/review, sparing use |
| `local` | Ollama at `host.docker.internal:11434` | free | Offline/private work (Ollama not installed yet) |

Prices are OpenRouter list prices at time of choice; re-check before swapping.

## Virtual keys

Each client gets its own key with per-key model lists, budgets and rate limits, stored in a small in-cluster Postgres. The database holds keys and spend logs only; it is rebuilt rather than backed up.

| Key alias | Client | Models | Budget | RPM |
|---|---|---|---|---|
| master | OpenCode, dev containers | all | 115 USD/30d (global) | none |
| hermes | Hermes Agent | fast, code | 5 USD/30d | 30 |

### Create a key

```bash
curl -s "$LLM_GATEWAY_URL/key/generate" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"key_alias":"name","models":["fast","code"],"max_budget":5,"budget_duration":"30d","rpm_limit":30,"metadata":{"client":"name"}}' \
  | jq -r .key
```

### Rotate a key

`POST /key/regenerate` with `{"key": "sk-..."}`.

### Revoke a key

`POST /key/delete` with `{"keys": ["sk-..."]}`.

### Rebuild after database loss

The database holds keys and spend logs only. **Tested 2026-11-08** (real event — PG18 wrote `PGDATA` to ephemeral storage and a restart wiped it; see the playbook 06 journal). The salt key (`LITELLM_SALT_KEY`) must be restored from the password manager; the `master` key survives (it is `LITELLM_MASTER_KEY`, an env var).

1. Confirm the database is on the PVC, not ephemeral storage. PG18's `PGDATA` is `/var/lib/postgresql/18/docker`, so the volume must mount at `/var/lib/postgresql` (not the pre-PG18 `/var/lib/postgresql/data`):
   `kubectl -n llm-gateway exec postgres-0 -- grep /var/lib/postgresql /proc/self/mountinfo`
2. Wait for Postgres: `kubectl -n llm-gateway rollout status sts/postgres`.
3. Restart LiteLLM so it reconnects and re-runs migrations: `kubectl -n llm-gateway rollout restart deploy/litellm && kubectl -n llm-gateway rollout status deploy/litellm`.
4. Admin routes (`/key/*`) are **not** on the Ingress — it only serves `/v1` and returns 404 for `/key/*`. Port-forward to reach them: `kubectl -n llm-gateway port-forward svc/litellm 4000:4000`, then use `http://localhost:4000`.
5. Recreate each virtual key with its **existing value piped from its Secret** into `/key/generate` — nothing rotates, no SOPS edit, no client restart:

   ```bash
   kubectl -n hermes get secret hermes -o jsonpath='{.data.LAB_GATEWAY_KEY}' \
   | base64 -d \
   | jq -R '{key: ., key_alias: "hermes", models: ["fast","code"], max_budget: 5, budget_duration: "30d", rpm_limit: 30, metadata: {client: "Hermes Agent"}}' \
   | curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:4000/key/generate \
     -H "Authorization: Bearer $LLM_GATEWAY_KEY" -H 'Content-Type: application/json' --data-binary @-
   ```

6. Persistence test — delete `postgres-0` and confirm the key count is unchanged: `kubectl -n llm-gateway delete pod postgres-0`, wait Ready, then `curl -s http://localhost:4000/key/list -H "Authorization: Bearer $LLM_GATEWAY_KEY"` shows the same keys.

## Alerts and resources

- `PostgresDown` (critical): the gateway's Postgres StatefulSet has no ready replicas for 10m — every virtual key fails without it.

Right-sized from a 3-day peak working-set (peak × 1.25, rounded to 16 Mi; limit = max(2× request, peak + 128 Mi)):

| Container | Request | Limit |
|---|---|---|
| litellm | 1104 Mi | 2304 Mi (2.25 Gi) |
| postgres | 80 Mi | 192 Mi |

## Budget

`max_budget: 115` USD with `budget_duration: 30d` in `config.yaml` (~100 EUR/month, matching the monthly limit on the OpenRouter key). Per-key budgets for individual harnesses can be added later via LiteLLM virtual keys.

## Operations

- Image is pinned (`litellm/litellm:v1.106.6` on the cluster; the laptop Compose file still has `v1.106.2`); update deliberately, it holds every key.
- Cluster: edited through Git (`platform/llm-gateway/`) and applied by Argo CD.
- Fallback (laptop): `docker compose -f ...\workstation\gateway\compose.yaml --project-directory ...\workstation\gateway up -d` from PowerShell.
- Sanity check: `curl $LLM_GATEWAY_URL/v1/models` with the bearer key must list all three aliases (`fast`, `code`, `reason`).
- Small reasoning models can burn max_tokens on reasoning; give chat calls token headroom.
