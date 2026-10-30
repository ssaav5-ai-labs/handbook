---
type: journal
title: Playbook 05 written - monitoring with Grafana Cloud and the LLM gateway on k3s
description: Wrote the playbook that sends the cluster's metrics, logs and events to Grafana Cloud through Alloy with alert rules in Git, moves the LiteLLM gateway from the laptop to k3s with traces to Langfuse Cloud, and right-sizes every app with measured numbers.
domain: platform
tags: [monitoring, grafana-cloud, alloy, litellm, gateway, playbook]
status: active
created: 2026-10-30
updated: 2026-10-30
visibility: public
reuse: lab-specific
related: [../../../playbooks/05-monitoring-gateway/PLAYBOOK.md, ../../decisions/0021-grafana-cloud-for-monitoring.md, ../../decisions/0022-llm-gateway-on-k3s.md]
blog: candidate
---

# 2026-10-30: Playbook 05 written - monitoring and the gateway on k3s

## Goal
Have playbook 05 ready right after playbook 04: the cluster is watched, and the LLM gateway runs where the next agents will run.

## What I did
- Wrote `playbooks/05-monitoring-gateway`: Grafana's `k8s-monitoring` chart (Alloy collectors, kube-state-metrics, node-exporter) as one Argo CD app, sending metrics, pod logs and events to a Grafana Cloud free-tier stack in the EU, plus the Prometheus operator's CRDs so `ServiceMonitor`s and `PrometheusRule`s work. Written against the chart's `4.6.0` layout; the run looks versions up again.
- First draft used a self-hosted VictoriaMetrics stack (about 0.8 GB). Shawn chose Grafana Cloud instead: capacity is the tightest constraint, and alerts from the cloud keep working when the lab is down. Recorded in [ADR-0021](../../decisions/0021-grafana-cloud-for-monitoring.md) (proposed), with VictoriaMetrics as the exit path when a third node arrives.
- Alert rules stay in Git: `PrometheusRule` objects that Alloy syncs to the cloud ruler. `LabSilent` (no metrics for 15 minutes) is the dead man's switch, evaluated outside the lab. Alerts go to Telegram; contact points and dashboards are set in the UI and written down.
- A series budget (under 5,000 of the free tier's 10,000) checked after each change, with only the needed metric families kept for Argo CD and the gateway.
- The gateway as plain manifests with the same master key and aliases, traces to Langfuse Cloud EU, plain HTTP on the LAN until there's a lab CA ([ADR-0022](../../decisions/0022-llm-gateway-on-k3s.md), proposed). The laptop Compose file becomes the fallback.
- Folded in the two playbook 04 follow-ups: Argo CD's memory requests are set from measured peaks in step 9 (with every other app), and an optional Part B moves the k3s token from `homelab-infra/.env` into SOPS.
- Ordered the steps so the agent's own model access never breaks mid-run: OpenCode keeps using the laptop gateway for the whole session, and the switch happens after it.
- The agent gets no Grafana Cloud read token; the human runs queries in Explore when a step needs numbers.
- Decision log: ADR-0019 and ADR-0020 were accepted in their files but still `proposed` in the index; fixed.

## What broke and how I fixed it
Nothing ran yet. Known risks for the run: Grafana Cloud's two Alertmanagers (synced rules notify through the ruler's one, not the Grafana one), the series limit, the chart's values layout changing between major versions, and LiteLLM's Langfuse integration defaulting to the US region (the EU host is set explicitly).

## Decisions made (link ADRs)
- [ADR-0021](../../decisions/0021-grafana-cloud-for-monitoring.md), proposed.
- [ADR-0022](../../decisions/0022-llm-gateway-on-k3s.md), proposed.

## Next
Merge this, set up the Grafana Cloud stack and token, Langfuse keys and Telegram bot from *Before you start*, then run playbook 05.
