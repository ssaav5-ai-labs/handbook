---
type: reference
title: Monitoring reference
description: What runs in the cluster and what in Grafana Cloud, pinned versions, endpoints (no credentials), the series budget, the Argo CD scrape, alert rules and the CI path, and Slack routing.
domain: platform
tags: [monitoring, grafana-cloud, alloy, prometheus, loki, alerting, mimirtool, argocd, slack]
status: active
visibility: public
reuse: lab-specific
created: 2026-11-04
updated: 2026-11-04
related: [index.md, ../../decisions/0021-grafana-cloud-for-monitoring.md, ../../decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md, runbook-alerts.md, ../../../playbooks/05-monitoring-gateway/PLAYBOOK.md]
blog: none
---

# Monitoring reference

## What runs where

- **Cluster:** the `monitoring` Argo CD app from Grafana's `k8s-monitoring` chart runs `alloy-metrics` (one StatefulSet replica), `alloy-logs` (a DaemonSet, one per node), `alloy-singleton` (one Deployment replica), kube-state-metrics and node-exporter. `prometheus-operator-crds` installs the Prometheus operator's types only (no operator). Alloy remote-writes metrics and pushes logs and events to Grafana Cloud.
- **Grafana Cloud:** Prometheus, Loki, Grafana, Grafana-managed alert rules and the Slack contact point. New stacks do **not** provision data-source-managed alerting or the Cloud Alertmanager, so there is no Alertmanager drop-down in Grafana.
- **Git:** `homelab-gitops/platform/monitoring/` holds the chart values, the SOPS Secret `grafana-cloud`, `rules.yaml` and the kustomization; `apps/prometheus-operator-crds.yaml` and `apps/monitoring.yaml` deliver them. `.github/workflows/alert-rules.yaml` imports the rules.

```
Git: platform/monitoring/rules.yaml ── CI (mimirtool) ──► Grafana-managed rules
cluster: Alloy ──remote write / push──► Grafana Cloud Prometheus + Loki
Grafana-managed rules ──► Slack #homelab-alerts
```

## Versions (2026-11-04)

| Component | Version |
|---|---|
| `k8s-monitoring` chart | 4.6.0 |
| Grafana Alloy | v1.21.3 |
| config-reloader | v0.94.2 |
| Alloy operator | 1.14.4 |
| kube-state-metrics | v2.20.0 |
| node-exporter | v1.12.1 |
| `prometheus-operator-crds` | 32.0.2 |
| `mimirtool` (CI) | 3.2.4 |
| `yq` (CI) | 4.54.1 |

`32.0.3` exists as a tag on GitHub but was not in the Helm repo when the run pinned it.

## Endpoints (no credentials)

| What | Value |
|---|---|
| Grafana | `https://<stack>.grafana.net` |
| Prometheus remote write | `https://<metrics-instance>.grafana.net/api/prom/push` |
| Loki push | `https://<logs-instance>.grafana.net/loki/api/v1/push` |
| Prometheus data source UID | `grafanacloud-prom` |
| Usage data source UID | `grafana-usage` |
| Tenant | `1` |
| Rules convert API (CI) | `https://<stack>.grafana.net/api/convert/` with header `X-Grafana-Alerting-Datasource-UID: grafanacloud-prom` |

The data-source **Details** page shows the right instance IDs (Basic auth User) but **internal** URLs ending in `-local-nlb.internal.grafana.net`; the public URL drops that suffix. A `GET` on the base returns `405`; a `POST` without a token returns `401`. The stack's endpoints are found at `https://grafana.com/profile/org`, not `/orgs/`.

Credentials: the Alloy token is in the SOPS Secret `monitoring/grafana-cloud` (`metrics-username`, `logs-username`, `token`); the CI rules token is the `GRAFANA_RULES_TOKEN` repo secret. Neither is in this page or in Git.

## Series budget

- Free tier: 10,000 active series; target under 5,000 after this playbook.
- Check the usage data source `grafana-usage` → `grafanacloud_instance_active_series`, and cross-check with `count({cluster="homelab"})` (not `count(up{...})`, which counts one series per target).
- This run: ~5,190 after step 6, ~1,970 after the Argo CD trim, ~2.12k after step 8.
- The Argo CD trim scrapes the **controller only** with `metricRelabelings` keeping `argocd_app_info`, `argocd_app_sync_total`, `argocd_app_k8s_request_total`, `argocd_cluster_info` and `up`; the server and repo-server ServiceMonitors are off. `up{namespace="argocd"}` is one series.
- To find the largest families: `topk(10, count by (__name__) ({cluster="homelab"}))`.

## Alert rules

`homelab-gitops/platform/monitoring/rules.yaml` holds one `PrometheusRule` named `lab`, group `lab`:

| Alert | Expression (short) | For | Severity |
|---|---|---|---|
| `LabSilent` | `absent_over_time(up{cluster="homelab"}[10m])` | 5m | critical |
| `ArgoCDAppOutOfSync` | `argocd_app_info{sync_status!="Synced"} == 1` | 30m | warning |
| `ArgoCDAppUnhealthy` | <code>argocd_app_info{health_status!~"Healthy&#124;Progressing"} == 1</code> | 15m | warning |
| `NodeSwapping` | `rate(node_vmstat_pswpin[10m]) > 100` | 30m | warning |
| `NodeDiskFilling` | root filesystem free `< 0.15` | 15m | warning |
| `NodeNotReady` | `kube_node_status_condition{condition="Ready", status="true", cluster="homelab"} == 0` | 5m | critical |
| `PodCrashLooping` | `increase(kube_pod_container_status_restarts_total{cluster="homelab"}[15m]) > 3` | 15m | warning |
| `LiteLLMDown` | `up{cluster="homelab", namespace="llm-gateway"} == 0 or absent(...)` | 5m | critical |

The CI workflow imports them; Alloy's rule sync is off.

- **PR:** `mimirtool rules lint` and `mimirtool rules check` (no token, no network).
- **Merge to `main`:** `yq` extracts every `PrometheusRule` `.spec` into **one** file with top-level `namespace: homelab` (`mimirtool` rejects a repeated namespace), runs `mimirtool rules diff` first (same `homelab` scope), fails on deletes outside `homelab`, then `mimirtool rules sync --concurrency 1 --namespaces=homelab`.
- Imported rules are **Provisioned** and read-only in the Grafana UI.
- The token is a service account `homelab-rules-sync` with Alerting rules reader/writer + set provisioning status, Datasources reader, and Folders creator/reader/writer; it has a 1-year expiry and a calendar reminder (see [ADR-0026](../../decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)).

**Stock rules are deliberately not installed.** The optional Kubernetes Monitoring stock rules were skipped (series budget, duplicates), so the rules we wanted (`NodeNotReady`, `PodCrashLooping`) are in Git. `LabSilent` is created in playbook step 5, not step 6, because the first sync otherwise left it out.

**Incident (2026-11-02):** the first `mimirtool rules sync` had no namespace scope and deleted 63 rule groups in Grafana's own `knowledge-graph` folder (Kubernetes Monitoring stock rules). They were not restored; the scope and diff gate are mandatory. `--namespaces=homelab` alone would still delete rules inside `homelab`, so the diff check is the second guard.

## Slack

- Contact point `slack`, integration Slack, recipient `#homelab-alerts` (or the webhook URL in the Webhook URL field, Token empty).
- Notification template title: alertname + node/namespace; the `summary` annotation goes in the body.
- Default policy: contact point `slack`, `group_by: [alertname, namespace]`, repeat interval 12h. A nested `severity="info"` policy was skipped (it needs a mute timing).
- Contact points, templates and policies are set in the Grafana UI for now; this section is the written record. Terraform is an open question.

## Resources (final, 6-hour peaks on 2026-11-04)

| Component | Peak MiB | Request | Limit |
|---|---:|---|---|
| argocd server | 49.3 | 64 Mi | 192 Mi |
| argocd controller | 682.2 | 704 Mi | 1280 Mi |
| argocd redis | 10.8 | 16 Mi | 144 Mi |
| argocd repo-server | 118.3 | 160 Mi | 512 Mi |
| alloy-metrics | 331.1 | 416 Mi | 832 Mi |
| alloy-logs | 72.6 | 96 Mi | 208 Mi |
| alloy-singleton | 70.0 | 96 Mi | 208 Mi |
| alloy-operator | 96.2 | 128 Mi | 256 Mi |
| kube-state-metrics | 33.0 | 48 Mi | 176 Mi |
| node-exporter | 20.9 | 32 Mi | 160 Mi |
| litellm | 551.1 | 704 Mi | 1 Gi |
| config-reloader ×4 | ~12 | 16 Mi | 144 Mi |

Node allocation of allocatable: **k3s-01** requests 1164 Mi (35%) / limits 2394 Mi (73%); **k3s-02** requests 1632 Mi (46%) / limits 3712 Mi (105%). Limits above 100% are caps, not reservations. These are 6-hour peaks; re-check with a 7-day window after a week.

## Checks and rotation

- `kubectl get nodes` (both Ready); `kubectl -n argocd get applications` (all Synced/Healthy); `kubectl -n monitoring get pods`; `kubectl top pods -n monitoring`.
- Grafana: **Alerting → Alert rules → `homelab`** (`LabSilent` `Normal`; all rules `Normal` unless something is firing); Explore with the Prometheus data source, `count({cluster="homelab"})`, `up{namespace="argocd"}` (one series), and `argocd_app_info`; usage data source for the series count.
- Rotate the Alloy token: new `glc_...` token in grafana.com → `sops edit platform/monitoring/secret.enc.yaml` (human) → PR → delete the old token.
- Rotate the rules token: new service-account token with **1-year expiry** → update the `GRAFANA_RULES_TOKEN` secret → re-run `alert-rules`. `401 "Expired API key"` means rotate and re-run; rules silently stop syncing until then.
- Debug sync failures from `kubectl -n argocd get application monitoring -o yaml` status and Alloy logs (`401`/`403`). Never render, decrypt or `kubectl exec` into a container with secrets.

## Related

- [Platform index](index.md)
- [Respond to a monitoring alert](runbook-alerts.md)
- [ADR-0021](../../decisions/0021-grafana-cloud-for-monitoring.md) (amended by ADR-0026)
- [ADR-0026](../../decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)
- [Playbook 05](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/05-monitoring-gateway/PLAYBOOK.md)
