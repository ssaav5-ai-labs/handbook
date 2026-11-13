---
type: runbook
title: SRE crews runbook
description: Diagnose and fix the SRE crews when investigations fail, the budget runs out, or credentials need rotation.
domain: ai-stack
tags: [crewai, mcp, agents, sre, hermes, runbook]
status: draft
visibility: public
reuse: portable
created: 2026-11-13
updated: 2026-11-13
related: [index.md, reference-sre-crews.md, reference-gateway.md, runbook-hermes.md]
---

# SRE crews runbook

## Crews down or slow

**Symptoms:** Hermes' alert-triage report says "the crew was not available" after a timeout, or the investigation takes longer than ~4 minutes with no result.

**Check order:**

1. **Pod status:**
   ```
   kubectl -n sre get pods -l app=sre-crews -o wide
   ```
   All four containers (`crews`, `k8s-mcp`, `grafana-mcp`, `git-sync`) must be `Ready`. If any are crashlooping, check their logs.

2. **Crews container logs (the MCP server + CrewAI runner):**
   ```
   kubectl -n sre logs deploy/sre-crews -c crews --since=10m
   ```
   Look for `outcome=error`, `timeout`, or `busy`. A "busy" response means another investigation is still running (the server enforces one-at-a-time).

3. **Sidecar logs:**
   - Kubernetes: `kubectl -n sre logs deploy/sre-crews -c k8s-mcp --tail=20`
   - Grafana: `kubectl -n sre logs deploy/sre-crews -c grafana-mcp --tail=20`
   MCP sidecars logging connection resets, 403s, or OOM kills point at token/auth failures or resource pressure.

4. **Hermes' MCP connection:**
   ```
   hermes mcp list
   ```
   (DM it) — confirm `crews` MCP server shows as connected. If not, restart the Hermes pod.

**Self-heal timing (drill 5):** scaling to 0 → Argo CD restores to 4/4 in ~11s. A pod move from a cordoned node takes ~60s. Neither window is long enough for Hermes to notice the crew is gone under normal polling.

## Reports wrong

**Symptoms:** Investigation report misidentifies the cause, invents a finding, or says "false positive" when the alert is real.

1. **Tool filter mismatch:** The static tool list in `homelab-agents/crews/src/sre_crews/tools.py` must match the MCP sidecars' actual tool names. mcp-grafana v2.2.0 renamed `list_alert_rules` → `alerting_rules_read`; if a new sidecar version renames or drops tools, the filter hides them silently and the investigator works with an incomplete view.

2. **Grafana SA token expired:** The Grafana Service Account token in `platform/sre-crews/secret.enc.yaml` (`GRAFANA_SERVICE_ACCOUNT_TOKEN`) has a **12-month** lifetime. Check the expiry in Grafana Cloud → Administration → Service Accounts. If expired, rotate it.

3. **The query returned nothing:** If the investigator's Grafana queries return empty series, check the datasource UID (`grafana-mcp` uses `--enabled-tools datasource,prometheus,loki,alerting`) and confirm the SA can query the datasource (needs "Query" permission on each datasource, not just a Viewer role).

4. **Context overflow:** The investigator hit context summarisation (visible in Langfuse traces as "context summary" calls). Evidence may be lost before the scribe writes the report. Consider limiting `pods_log` tail or narrowing the investigation scope.

## The budget

**Mechanism:** Each gateway key has a `max_budget` (USD) over a `budget_duration` (the gateway default is 30 days). The `crews` key is set to `max_budget: 5.0`. When cumulative 30-day spend exceeds the limit, LiteLLM returns HTTP 402 and the investigation fails.

**Monitoring:**
```
litellm_remaining_api_key_budget_metric{api_key_alias="crews"}
```
in Grafana. A `CrewsBudgetLow` alert (step 10) fires when it drops below $1.00. Per-drill cost is ~$0.03 (7 LLM calls per investigation), so the key handles ~150 investigations per 30-day window at current usage.

**Increase the budget via `/key/update`:**

Port-forward to the gateway:
```
kubectl -n llm-gateway port-forward svc/litellm 4000:4000
```

Then, in another terminal:
```
curl -X PUT http://localhost:4000/key/update \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key_alias": "crews", "max_budget": 10.0}'
```

Verify the new limit took effect:
```
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://localhost:4000/key/info?key_alias=crews | jq '.info.max_budget'
```

The master key is in `platform/llm-gateway/secret.enc.yaml` as `LITELLM_MASTER_KEY` (sops-encrypted; use `sops exec-env` to run the command with it).

Alternatively, wait for the 30-day window to roll (the spend counter resets automatically).

## Turning the crews off

**Scale to 0 in Git:**

In `platform/sre-crews/deployment.yaml`, set `replicas: 0`, merge. Argo CD applies it and the pod terminates. Hermes' alert-triage skill falls back to its own read-only checks (the "crew was not available" path).

To turn them back on, revert `replicas` to the previous value.

**Hermes fallback behaviour is UNTESTED** — drill 1 was Hermes-by-design (no crew call), not an `investigate_alert` error. The fallback clause in the alert-triage skill says Hermes runs the read-only checks table, but the exact behaviour when the crew tool times out or errors has not been observed. Consider triggering a PlaybookInjection rule after scaling to 0 and verifying the fallback report arrives.

## Turning `lab-actions` off

1. Remove `lab_actions` from Hermes' `managed/config.yaml` `mcp_servers` list.
2. Set `replicas: 0` in `platform/sre-crews/lab-actions-deployment.yaml`.
3. Merge both.

With `lab-actions` gone, the `restart_workload` tool is unavailable to Hermes entirely. Re-enable by reverting both changes.

## Rotating credentials

All three secrets live in `platform/sre-crews/secret.enc.yaml` (sops-encrypted):

| Secret | Set to | Consumer |
|---|---|---|
| `CREWS_MCP_TOKEN` | a long random bearer token (`openssl rand -hex 32`) | Hermes' `managed/config.yaml` `mcp_servers.crews.headers.Authorization: Bearer <token>` |
| `LAB_ACTIONS_TOKEN` | another random bearer token | Hermes' `managed/config.yaml` `mcp_servers.lab_actions.headers.Authorization: Bearer <token>` |
| `GRAFANA_SERVICE_ACCOUNT_TOKEN` | a Grafana Cloud SA token (`glsa_...`) | the `mcp-grafana` init container via `secretKeyRef` |

**Procedure for each:**

1. **Create the new value.** For `CREWS_MCP_TOKEN` / `LAB_ACTIONS_TOKEN`: `openssl rand -hex 32`. For the Grafana token: create a new SA token in Grafana Cloud (12-month expiry), copy it.
2. **Update the sops secret:** `sops edit platform/sre-crews/secret.enc.yaml` (or `sops exec-env` and regenerate). Replace the old value with the new one.
3. **Update the consumer config.** For the MCP tokens, also update the bearer header value in `platform/hermes/managed/config.yaml`. The Grafana token is consumed only by the sidecar, so no config update is needed (only the secret).
4. **Merge.** Argo CD syncs the secret and the config. Restart the sre-crews pod (`kubectl -n sre delete pod -l app=sre-crews` or wait for the configMapGenerator hash-suffix to roll Hermes).
5. **Verify.** If `CREWS_MCP_TOKEN` changed: DM Hermes "hermes mcp list" and confirm the `crews` server shows as connected. If the Grafana token changed: `kubectl -n sre logs deploy/sre-crews -c grafana-mcp --tail=5` should show no 403s.