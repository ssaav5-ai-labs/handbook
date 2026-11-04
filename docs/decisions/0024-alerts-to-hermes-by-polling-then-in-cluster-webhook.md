---
type: adr
title: Bring Grafana Cloud alerts to Hermes by polling from the cluster now, and by an in-cluster webhook once alerting runs in the lab
description: The lab opens no inbound path; a script-only Hermes cron job polls Grafana Cloud's firing alerts every 2 minutes with a read-only token and wakes the model only for new alerts, while Hermes' webhook route is kept cluster-internal for a future in-lab alert manager.
domain: ai-stack
tags: [hermes, grafana-cloud, alerting, webhooks, cron, polling, security]
status: proposed
created: 2026-11-01
updated: 2026-11-04
visibility: public
reuse: portable
related: [0021-grafana-cloud-for-monitoring.md, 0023-hermes-on-k3s-pod-as-sandbox.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0024. Bring Grafana Cloud alerts to Hermes by polling from the cluster now, and by an in-cluster webhook once alerting runs in the lab

## Context
Grafana Cloud (ADR-0021) evaluates the lab's alerts and sends them to Slack. Hermes (ADR-0023) should also get each new alert as structured data and post a first diagnosis. Grafana Cloud can only call public HTTPS addresses; the lab is on a home network with no inbound ports, no public name and no domain. Alerting may move into the lab later (self-hosted Grafana or Alertmanager), and then the sender would sit inside the cluster.

Checked against Hermes v0.22.x: it has a built-in webhook receiver with HMAC checks, and a scheduler whose jobs can run a pre-check script that decides whether to wake the model at all (`{"wakeAgent": false}`). Grafana's webhook can sign requests in a format Hermes accepts (body-only HMAC in an `X-Webhook-Signature` header; Grafana's timestamped format differs from Hermes').

## Options considered
1. **A tunnel for Grafana's webhook** (Tailscale Funnel or Cloudflare Tunnel): instant and push-based, but it puts a public endpoint on the lab, adds an operator or connector and its credentials, and Cloudflare needs a domain. Becomes unnecessary once alerting is in the lab.
2. **Slack as the trigger:** Grafana's Slack message mentions Hermes, which reads it. No new parts, but the alert arrives as text formatted for people, anyone holding the Slack webhook URL could wake Hermes, and Hermes would act with its full chat tools.
3. **Polling from the cluster:** a script-only job fetches firing alerts every 2 minutes with a read-only token and wakes Hermes only for new ones. No inbound path, no model cost while quiet; diagnoses arrive up to about 2 minutes after Grafana's message; the token lives in the cluster.
4. **No automatic diagnosis:** only ask Hermes by hand in the alert's thread.

## Decision
Option 3 now, with option 4 always available (an @mention in an alert's thread works with no extra setup):
- A Grafana service account with only the alert-reading role (or Viewer where fixed roles aren't offered), its token in SOPS and forwarded only to the cron script.
- `grafana-alerts.py` (in `homelab-gitops`, copied into Hermes at every start) keeps the fingerprints it has seen, sends only labels, annotations, start time and link (truncated) for new firing alerts, reports its own failures at most once an hour, and is tested in CI with fixtures.
- The diagnosis runs as an unattended cron session with the `alert-triage` skill: dangerous commands denied, read-only RBAC, output to `#homelab-alerts`.

When alerting moves into the lab, the in-cluster alert manager posts to Hermes' webhook route (already configured: cluster-internal Service, only the `monitoring` namespace may connect, HMAC secret in SOPS, same skill and delivery), and the cron job, the script and the Grafana token are deleted.

## Consequences
- Nothing in the lab is reachable from the internet; Hermes and its poller only connect out.
- A quiet lab costs no model calls; each new alert costs one diagnosis. Resolved alerts aren't diagnosed.
- Diagnoses lag Grafana's own Slack message by up to about 2 minutes. If Grafana Cloud's API or the token fails, alerts still reach Slack; Hermes posts one error an hour until it's fixed.
- A read-only Grafana token now lives in Hermes' pod, with a one-year expiry to renew.
- The webhook route and the poller feed the same skill and the same channel, so moving alerting into the lab changes the trigger, not the behaviour.
- Remote access from the phone to the lab's own UIs is a separate question (Tailscale without public exposure is the leaning), no longer tied to alerts.

## In a team or enterprise setting
Pull versus push is a real trade-off there too: push (webhooks) is faster but needs an exposed, authenticated endpoint and a trust boundary in front of it; pull keeps the network closed and the credential narrow, at the cost of latency and polling load. Many teams start with pull from inside the network and switch to push once the alerting system sits on the same network as its consumers, which is the path planned here.
