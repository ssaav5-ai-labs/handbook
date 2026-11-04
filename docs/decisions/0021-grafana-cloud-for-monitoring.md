---
type: adr
title: Monitor the cluster with Grafana Cloud's free tier through Grafana Alloy, alert rules in Git, alerts to Slack
description: Only collectors run on k3s (Grafana's k8s-monitoring chart, managed by Argo CD); metrics, logs, events, dashboards and alerting live in a Grafana Cloud free-tier stack; alert rules are PrometheusRule objects in Git that CI imports into Grafana-managed rules, and a LabSilent rule pages Slack when the lab stops sending data.
domain: platform
tags: [monitoring, grafana-cloud, alloy, alerting, slack, capacity]
status: accepted
created: 2026-10-30
updated: 2026-11-04
visibility: public
reuse: portable
related: [0012-langfuse-cloud-until-capacity.md, 0016-zram-swap-on-k3s-nodes.md, 0019-gitops-with-argo-cd-app-of-apps.md, 0020-secrets-in-git-with-sops-age-ksops.md, 0026-grafana-managed-alert-rules-synced-from-git-by-ci.md, ../domains/platform/index.md, ../domains/platform/reference-monitoring.md, ../domains/platform/runbook-alerts.md]
supersedes: []
superseded_by: []
amended_by: [0026-grafana-managed-alert-rules-synced-from-git-by-ci.md]
blog: candidate
---

# 0021. Monitor the cluster with Grafana Cloud's free tier through Grafana Alloy, alert rules in Git, alerts to Slack

## Context
The cluster now runs from Git (ADR-0019) and is about to host the LLM gateway, then Hermes, the SRE agents and the AI factory (Backstage alone wants 2 to 4 GB). Nothing watches it yet. Each k3s node has about 3.4 GB for pods, and Argo CD plus the k3s add-ons already use about 2.3 GB of the 7 GB the two nodes have. The open question leaned towards a self-hosted VictoriaMetrics stack; Grafana Cloud's free tier was listed as a way to save capacity (2026-10-27).

## Options considered
1. **kube-prometheus-stack**, self-hosted: the industry default. Prometheus alone wants 1 GB or more; it doesn't fit.
2. **victoria-metrics-k8s-stack**, self-hosted: metrics, logs, alerting and Grafana in about 0.8 GB, 30 days of data, no series limit, data stays local. Monitoring shares the fate of the cluster it watches, so it needs an outside dead man's switch.
3. **Grafana Cloud free tier**, with only collectors in the cluster (Grafana's `k8s-monitoring` chart: Alloy, kube-state-metrics, node-exporter), about 0.5 GB. Storage, Grafana, the ruler and Alertmanager are hosted. Limits: 10k active series, 50 GB of logs, 14 days of retention; data leaves the lab; reading it needs a cloud token.

## Decision
Option 3, chosen by Shawn on 2026-10-30. Capacity is the lab's tightest constraint, and alerting from outside the lab keeps working when the lab is down, which a self-hosted stack can't do on its own.

**Amended 2026-11-02 by [ADR-0026](0026-grafana-managed-alert-rules-synced-from-git-by-ci.md):** new Grafana Cloud stacks don't provision data-source-managed alerting or the Cloud Alertmanager, so Alloy's rule sync has no Alertmanager that reaches Slack. CI now imports the same `PrometheusRule`s into Grafana-managed rules. The rest of this ADR holds.

- One Argo CD app, `monitoring`, from `homelab-gitops/platform/monitoring`, plus the Prometheus operator's CRDs (no operator) so that `ServiceMonitor`s and `PrometheusRule`s are valid types.
- The chart's default allow lists stay on, and every new scrape keeps only the metric families it needs. Budget: under 5,000 active series after playbook 05, leaving room under the 10,000 limit for later playbooks.
- Alert rules are `PrometheusRule` objects in Git. CI imports them into Grafana-managed rules with `mimirtool rules sync --namespaces=homelab` ([ADR-0026](0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)); Alloy's rule sync is off. The most important rule is `LabSilent` (no metrics from the lab for 15 minutes), evaluated in the cloud.
- Alerts go to Slack (`#homelab-alerts`). Contact points, notification policies, templates and dashboards are set in the Grafana Cloud UI and written down in `reference-monitoring.md`, until they're managed as code.
- The Alloy token (`metrics:write`, `logs:write`, `rules:read`, `rules:write`) is in SOPS. The CI rules token is a separate service-account token in the `GRAFANA_RULES_TOKEN` repo secret, expiring after one year. The AI agent gets no read token; the human runs queries in Explore when a step needs numbers.

## Consequences
- About 0.3 GB more room for the next playbooks than the self-hosted option, and no metrics or logs volumes on the nodes.
- Alerts survive the lab: power cut, both nodes down or the network out all page Slack.
- The series limit is a real constraint: each new app's metrics are filtered on the way in, and the count is checked after each playbook.
- The CI rules token is a write path into Grafana. The workflow is scoped to `--namespaces=homelab`, runs `rules diff` first and fails on deletes outside that namespace; an unscoped sync once deleted 63 stock rule groups (ADR-0026). It expires after one year: a `401 "Expired API key"` in `alert-rules` means rotate it and re-run.
- 14 days of history: enough for operating the lab, too little for long trends. Export anything worth keeping for posts.
- Metrics and logs leave the lab. Nothing sensitive is in them; pod logs must not print secrets (the same rule as for transcripts).
- The SRE agents in playbook 07 need a scoped read token to query their own cluster. Decide there whether that's a Grafana Cloud token for an MCP server or a small local store.
- A single `alloy-metrics` replica is a gap while its node is down; `LabSilent` waits long enough not to page for a reschedule.
- Exit path: Alloy can remote-write anywhere. Moving to self-hosted VictoriaMetrics (option 2) when a third node arrives means a new destination in the values; the rules in Git move with it.

## In a team or enterprise setting
The same pattern at scale: collectors in every cluster, a hosted or central backend, alert rules as code in the same repo as the workloads, and the ruler running somewhere the monitored systems can't take down. Teams add cardinality budgets per service, a vendor-neutral collector (Alloy or the OpenTelemetry Collector) so the backend can change, and contact points as code (Terraform) with on-call tooling behind them.
