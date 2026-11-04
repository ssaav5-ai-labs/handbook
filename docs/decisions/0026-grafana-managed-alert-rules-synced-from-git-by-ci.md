---
type: adr
title: Sync Grafana-managed alert rules from Git with CI, not Alloy
description: New Grafana Cloud stacks don't provision data-source-managed alerting or the Cloud Alertmanager, so a GitHub Action imports the PrometheusRule objects from Git into Grafana-managed rules with mimirtool, scoped to the homelab namespace, and routes them to Slack.
domain: platform
tags: [monitoring, grafana-cloud, alerting, gitops, ci, mimirtool, slack]
status: accepted
created: 2026-11-02
updated: 2026-11-04
visibility: public
reuse: portable
related: [0021-grafana-cloud-for-monitoring.md, 0019-gitops-with-argo-cd-app-of-apps.md, 0024-alerts-to-hermes-by-polling-then-in-cluster-webhook.md, ../domains/platform/reference-monitoring.md, ../domains/platform/runbook-alerts.md]
supersedes: []
superseded_by: []
amends: [0021-grafana-cloud-for-monitoring.md]
blog: candidate
---

# 0026. Sync Grafana-managed alert rules from Git with CI, not Alloy

## Context
ADR-0021 put the lab's alert rules in Git as `PrometheusRule` objects and had Grafana Alloy sync them to the Grafana Cloud ruler. That works on stacks with the Cloud Alertmanager. New Grafana Cloud stacks provision neither data-source-managed alerting nor the Cloud Alertmanager ("not provisioned in new stacks"; existing stacks are unaffected), and "Manage alerts via Alerting UI" cannot be turned on for the provisioned `-prom` data source. The rules arrive at the ruler but there is no Alertmanager that reaches Slack, so `LabSilent` and `PlaybookTest` never notified.

The rules still need to live in Git and be reviewed like everything else. The supported path on a new stack is Grafana-managed rules, which can be imported from Prometheus rule YAML through Grafana's Mimir-compatible convert API.

## Options considered
1. **Keep Alloy rule sync and add a Cloud Alertmanager:** not available on a new stack; would need a support change or a different stack.
2. **Create the rules in the Grafana UI:** works, but Git stops being the source of truth, changes skip review, and drift is invisible.
3. **Import the Git rules into Grafana-managed rules from CI:** keeps Git as the source of truth, reviews every change in a PR, and uses the supported convert API. The CI token becomes a write path, so it must be scoped and guarded.

## Decision
Option 3. A GitHub Action on merge to `main`:

- Scans the repo for every `PrometheusRule`, extracts each `.spec` with `yq`, and merges the groups into **one** file with top-level `namespace: homelab`; `mimirtool` rejects a repeated namespace.
- Runs `mimirtool rules diff` first (against the same `homelab` scope) and fails on deletes outside `homelab`, then `mimirtool rules sync --concurrency 1 --namespaces=homelab` against `https://<stack>.grafana.net/api/convert/` with the header `X-Grafana-Alerting-Datasource-UID=grafanacloud-prom`.
- Authenticates with the repo secret `GRAFANA_RULES_TOKEN`, a service account `homelab-rules-sync` with Alerting rules reader/writer + set provisioning status, Datasources reader, and Folders creator/reader/writer. The token is never in Git. It gets an explicit **1-year expiry** and a calendar reminder; the first run's default short expiry broke syncing with `401 "Expired API key"`.
- Leaves Alloy's rule sync off (`rules.enabled: false`); Alloy still writes metrics and logs. Imported rules are **Provisioned** and read-only in the Grafana UI.
- Sends alerts to Slack (`#homelab-alerts`) through a Slack contact point, with a notification template (title = alertname + node/namespace, `summary` annotation in the body) and `group_by: [alertname, namespace]`. Contact points, templates and policies stay in the UI for now and are written down in `reference-monitoring.md`.

## Consequences
- Git is the source of truth for alert rules, every change is reviewed in a PR, and the UI cannot drift.
- The CI token can write rules. The `--namespaces=homelab` scope and the diff gate are not optional: an early unscoped sync deleted 63 rule groups in Grafana's own `knowledge-graph` folder (optional Kubernetes Monitoring stock rules). They were not restored: they duplicate lab alerts and cost series; add any stock rule we want to Git deliberately. `NodeNotReady` and `PodCrashLooping` were added this way.
- A token expiry silently stops syncing; the workflow fails with `401 "Expired API key"`, so the calendar reminder and the failure alert matter.
- Rules are read-only in the UI, which is the point, but ad-hoc edits now require a PR.
- The Grafana Cloud free tier and the rest of ADR-0021 are unchanged; this only replaces how rules reach Grafana.

## In a team or enterprise setting
The same pattern: rule YAML in the workload repo, a CI job with a scoped service account, a diff gate that fails on deletes outside the team's namespace, and a reviewable PR for every alert change. Larger teams add a Terraform or Crossplane layer, a dedicated alerting repo, and a staging stack where the diff runs before production.
