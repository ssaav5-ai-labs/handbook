---
type: runbook
title: Hermes is down, silent, or not diagnosing
description: Diagnose and recover the lab operator assistant - pod, logs, Slack, gateway key, the Grafana alert poller, and how to stop it fast or rotate its credentials.
domain: ai-stack
tags: [hermes, slack, grafana-cloud, alerting, runbook]
status: draft
visibility: public
reuse: lab-specific
created: 2026-11-08
updated: 2026-11-08
related: [reference-hermes.md, reference-gateway.md, index.md]
---

# Hermes is down, silent, or not diagnosing

Hermes runs in namespace `hermes` (Deployment `hermes`, one pod), answers DMs over Slack Socket Mode, and polls Grafana Cloud Alertmanager every 2 minutes through the `grafana-alerts` cron job. Its state (memory, cron jobs) lives on the `hermes-data` PVC, not in Git.

## Hermes is down or silent

Work from the pod outward.

1. **Pod.** `kubectl -n hermes get pods` — is `hermes-*` Running and Ready? `kubectl -n hermes describe pod -l app=hermes` for events, restarts or `OOMKilled`. The Deployment is `Recreate`, so a crash just replaces the pod.
2. **Logs.** `kubectl -n hermes logs deploy/hermes -c hermes` (also `-c seed` and `-c git-sync` for the init/sidecar containers).
3. **Slack tokens.** Slack runs over Socket Mode with two tokens from the `hermes` Secret: `SLACK_APP_TOKEN` (`xapp-`, enables Socket Mode) and `SLACK_BOT_TOKEN` (`xoxb-`). If either was revoked or expired, Hermes runs but cannot receive DMs or post.
4. **Gateway key budget.** Hermes calls the LLM gateway with its own virtual key (`LAB_GATEWAY_KEY`, alias `hermes`). If that budget is spent every reply fails. Watch `HermesBudgetLow` (info), or check `litellm_remaining_api_key_budget_metric{api_key_alias="hermes"}`.
5. **Socket Mode.** The app-level token is what keeps the bot connected; without it the bot is silent even though the pod is healthy.

## Alerts arrive without diagnosis

The poller is a Hermes cron job (`grafana-alerts`) with a pre-check script that only wakes the agent on new firing alerts.

1. `hermes cron list` — is `grafana-alerts` still present? Cron jobs live in Hermes' state DB on the `/opt/data` volume; a rebuilt PVC drops them.
2. Job's last error — `hermes cron run grafana-alerts` and read the output (or the job's stored last error).
3. Grafana token expiry — `GRAFANA_ALERTS_TOKEN` (in the `hermes` Secret) is a Grafana Cloud service account token; when it expires the poll returns `401` and nothing fires.
4. Grafana's API — the poller URL is `GRAFANA_ALERTS_URL` in `platform/hermes/managed/.env`; confirm it still points at the right Grafana Cloud stack and `filter=grafana_folder="homelab"`.

## Turn it off fast

- Alerts only, keep chat: `kubectl -n hermes exec deploy/hermes -c hermes -- hermes cron pause grafana-alerts`.
- Everything: set `replicas: 0` in `platform/hermes/deployment.yaml` and let Argo CD apply it (scale back up the same way).

## Rotate a credential

Every credential lives in the `hermes` SOPS Secret (`platform/hermes/secret.enc.yaml`); edit with `sops edit` and restart the pod to load it (`kubectl -n hermes rollout restart deploy/hermes`).

| Credential | Where it comes from | To rotate |
|---|---|---|
| `SLACK_APP_TOKEN` | Slack App → Basic Information → App-Level Tokens | regenerate, `sops edit` |
| `SLACK_BOT_TOKEN` | Slack App → OAuth & Permissions | regenerate, `sops edit` |
| `GRAFANA_ALERTS_TOKEN` | Grafana Cloud → service account | rotate, `sops edit` |
| `LAB_GATEWAY_KEY` | LiteLLM virtual key (`hermes`) | `POST /key/regenerate`, then `sops edit` |
| `WEBHOOK_SECRET` | in-lab alert manager HMAC | generate random, `sops edit` |

`LAB_GATEWAY_KEY` also has to stay in sync with the LiteLLM database — regenerate it through the gateway first (see the gateway runbook), then put the new value into SOPS.
