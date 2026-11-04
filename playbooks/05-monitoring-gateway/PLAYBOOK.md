---
type: playbook
title: Monitor the cluster with Grafana Cloud and run the LLM gateway on k3s
description: Sends the cluster's metrics, logs and events to Grafana Cloud's free tier through Grafana Alloy, imports alert rules from Git as Grafana-managed rules with CI, pages Slack, moves the LiteLLM gateway from the laptop to the cluster with traces to Langfuse Cloud, then right-sizes every app with measured numbers.
domain: platform
tags: [monitoring, grafana-cloud, alloy, prometheus-rules, alerting, mimirtool, ci, slack, litellm, langfuse, opentelemetry, argocd, sops]
status: draft
created: 2026-10-30
updated: 2026-11-04
visibility: public
reuse: portable
repo: homelab-gitops
depends_on: [../04-argocd]
related:
  - ../../docs/decisions/0008-vendor-neutral-ai-stack.md
  - ../../docs/decisions/0012-langfuse-cloud-until-capacity.md
  - ../../docs/decisions/0019-gitops-with-argo-cd-app-of-apps.md
  - ../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md
  - ../../docs/decisions/0021-grafana-cloud-for-monitoring.md
  - ../../docs/decisions/0022-llm-gateway-on-k3s.md
  - ../../docs/decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md
  - ../../docs/domains/platform/reference-argocd.md
  - ../../docs/domains/platform/reference-monitoring.md
  - ../../docs/domains/platform/runbook-alerts.md
  - ../../docs/domains/platform/howto-secrets-sops.md
  - ../../docs/domains/ai-stack/reference-gateway.md
  - ../../docs/domains/k3s/reference-k3s.md
  - ../../docs/open-questions/index.md
blog: candidate
---

# Monitor the cluster with Grafana Cloud and run the LLM gateway on k3s

## What you'll have at the end
The cluster is watched from outside. Grafana Alloy, deployed by Grafana's `k8s-monitoring` chart as one Argo CD app, `monitoring`, collects metrics (kubelet, cAdvisor, kube-state-metrics, node-exporter, Argo CD, the gateway), pod logs and Kubernetes events, and sends them to a Grafana Cloud free-tier stack ([ADR-0021](../../docs/decisions/0021-grafana-cloud-for-monitoring.md)). Storage, dashboards, queries and alerting run in Grafana Cloud, so the lab spends about 0.5 GB on collectors instead of about 0.8 GB on a whole stack, and the alerts keep working when the lab is down: a `LabSilent` rule pages you when the cluster stops sending data.

Alert rules live in Git as `PrometheusRule` objects. CI imports them into Grafana-managed rules with `mimirtool` ([ADR-0026](../../docs/decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)), so a new alert is a pull request like everything else. Alerts reach `#homelab-alerts` on Slack (and your phone, if Slack is installed).

The LLM gateway moves from the laptop to the cluster as a second app, `llm-gateway`: the same LiteLLM aliases (`fast`, `code`, `reason`), its keys in SOPS, traces to Langfuse Cloud over OpenTelemetry ([ADR-0012](../../docs/decisions/0012-langfuse-cloud-until-capacity.md), [ADR-0022](../../docs/decisions/0022-llm-gateway-on-k3s.md)), and its metrics in Grafana Cloud. The laptop gets about 400 MB back and keeps the old Compose file as a fallback for when the cluster is down.

Finally, every app's memory requests are set from what Grafana Cloud measured during the run, including the Argo CD follow-up from playbook 04. An optional last part moves the k3s token from `homelab-infra/.env` into SOPS.

```
homelab-gitops (main) ── Argo CD (root) ──► apps/prometheus-operator-crds.yaml (CRDs only, no pods)
                                     ├──► apps/monitoring.yaml   ──► namespace monitoring
                                     └──► apps/llm-gateway.yaml  ──► namespace llm-gateway

monitoring:  alloy-metrics ──scrape──► kubelet, cAdvisor, kube-state-metrics, node-exporter,
                                       ServiceMonitors (Argo CD, LiteLLM)
             alloy-logs (per node) ──► pod logs        alloy-singleton ──► events
                   │ remote write / push (token from SOPS)
                   ▼
Grafana Cloud (free): Prometheus (metrics), Loki (logs), Grafana-managed rules ──► Slack
                      Grafana: https://<stack>.grafana.net
GitHub Actions: mimirtool rules sync ──► Grafana-managed rules (from platform/monitoring/rules.yaml)

llm-gateway: litellm ──► OpenRouter          ──OTel──► Langfuse Cloud (EU)
             in cluster: http://litellm.llm-gateway.svc:4000
             from the laptop: http://llm.<k3s-01-ip>.nip.io   (after the session)
```

What this playbook does not do: scrape the k3s control plane (scheduler, controller manager and etcd run inside the k3s process without metrics endpoints; see the open questions), virtual keys and a database for the gateway (playbook 06, when Hermes becomes the second client), TLS for the gateway on the LAN (it comes with lab DNS and a lab CA), and dashboards, contact points or notification policies as code (they're set up in the Grafana Cloud UI and written down; Terraform for them is an open question). Alert rules are code: CI imports them from Git ([ADR-0026](../../docs/decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)).

## Before you start 🧑
- [ ] Playbook 04 is done: in the `homelab-gitops` container, `kubectl -n argocd get applications` shows `argocd`, `root` and `sops-canary` `Synced` and `Healthy`.
- [ ] The handbook on Windows is on `main` and up to date (it includes this playbook).
- [ ] The laptop gateway is running (`docker ps` in PowerShell shows `llm-gateway`). **It stays running for the whole session**: OpenCode talks to it. The switch to the cluster gateway happens after the session.
- [ ] OpenRouter has credit: the playbook 03 run stalled on a `402` (in-flight credit limit). Check `https://openrouter.ai/settings/credits` and the key's limit.
- [ ] **A Grafana Cloud stack.** Sign up at `https://grafana.com` (free plan), and create a stack in an **EU region** (same reasoning as Langfuse, ADR-0012). Note the stack's Grafana address (`https://<stack>.grafana.net`). Check the current free-tier limits on `https://grafana.com/pricing` (when this was written: 10k active metric series, 50 GB of logs, 14 days of retention); the playbook keeps the series well under the limit.
- [ ] **Its endpoints and a write token.** Open `https://grafana.com/profile/org` → the stack → **Details**. The data sources show the right instance IDs (Basic auth User), but their URLs are **internal** (`-local-nlb.internal.grafana.net`); the public URL drops `-local-nlb.internal` and ends in `/api/prom/push` (metrics) or `/loki/api/v1/push` (logs). Check: `GET` on the base returns `405`, `POST` with no token returns `401`. Don't use the "Hosted Prometheus metrics" connection page's token: its `set:alloy-data-write` scope lacks rules scopes. Then **Access Policies** (grafana.com → Security): create a policy `homelab-alloy` for this stack with scopes `metrics:write`, `logs:write`, `rules:read` and `rules:write`, and a token for it. The UI has no `rules: delete` scope; `rules: write` covers it, and a generic "combined read and write" warning is expected. Save the token (`glc_...`) and the two instance IDs in the password manager. The URLs aren't secret; tell the agent in step 2.
- [ ] **Langfuse Cloud keys.** At `https://cloud.langfuse.com` (EU region), open or create the project for the lab, then **Settings → API Keys → Create new API key**. Save the public key (`pk-lf-...`) and the secret key (`sk-lf-...`) in the password manager.
- [ ] **A Slack incoming webhook for alerts.** In the `ssaav5-ai-labs` Slack workspace, create an incoming webhook for `#homelab-alerts` (or use an existing one); save the URL (`https://hooks.slack.com/services/T.../.../...`) in the password manager. It goes only into Grafana Cloud's contact point (step 5), never into Git or the agent's terminal.
- [ ] Only one dev container runs at a time (8 GB laptop). In **PowerShell**, start the `homelab-gitops` container and open a shell:
```powershell
devpod up "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops" --ide none
ssh homelab-gitops.devpod
```
If `ssh <repo>.devpod` doesn't work on your Windows setup, use the Docker fallback in `docs/domains/workstation/runbook-daily-start.md`.
- [ ] In the container: `gh auth status` (if it says not logged in: `gh auth login -h github.com -s repo,workflow`, enter the code on github.com, then click the final green **Authorize**), `git checkout main && git pull`, `kubectl get nodes` (both `Ready`), and `curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $LLM_GATEWAY_KEY" "$LLM_GATEWAY_URL/v1/models"` prints `200` (the laptop gateway answers).

## Kick it off
In the container's terminal:
```bash
opencode
```
> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/05-monitoring-gateway`.

If you're resuming an earlier run, say so: the agent checks each step's Verify first and skips what's done.

**Keep a second terminal for yourself.** Steps 3 and 7 ask you to type secrets with `sops edit`, which the agent must never see. Open a second terminal on the laptop and run `ssh homelab-gitops.devpod` (or the Docker fallback above). That shell is yours, not the agent's. Both shells share the repo folder; don't create a branch in the human shell, the agent already did.

**Git workflow (from playbook 04):** every change is a branch created **before** the commit, a PR, `ci` green, you squash-merge, then `git checkout main && git pull`. After a merge, a new app appears when `root` next polls Git (up to 3 minutes); `kubectl -n argocd annotate application root argocd.argoproj.io/refresh=normal --overwrite` skips the wait.

**The agent can't read Grafana Cloud.** It has no read token, by design: a token in its terminal would end up in the transcript. Where a step needs numbers from Grafana Cloud, you run the query in **Explore** and give the agent the result (a CSV saved to `.runs/`, or the numbers pasted in).

## Steps

### 1. Measure the headroom
**Why:** Each node has about 3.4 GB for pods after k3s's reservations, and the scheduler places pods by their memory **requests**, not by what they use. This playbook adds roughly 0.9 GB of real use (collectors and the gateway). Measuring first tells you whether it fits, and gives the "before" numbers for the journal and the right-sizing in step 9.
**Actions:**
- On a new handbook branch, open today's journal entry.
- `kubectl top nodes`; `kubectl describe nodes | grep -A8 'Allocated resources'` (requests and limits per node); `kubectl get nodes -o custom-columns=NAME:.metadata.name,ALLOCATABLE:.status.allocatable.memory`.
- Per node: free for new requests = allocatable minus the memory requests already allocated. Write a table with that, and the planned requests for this playbook (from steps 2 and 7: about 0.5 GiB for the collectors, 0.4 GiB for the gateway).

**Verify:** The table is in the journal, and each node's free requestable memory is above 1 GiB, or the larger of the two is above 1.5 GiB. If not, stop: the right-sizing in step 9 comes first (lower Argo CD's requests with the numbers from playbook 04), then continue.
**Record:** Journal: the table, "before".

### 2. Pin the collectors and write their values
**Why:** Grafana's `k8s-monitoring` chart is what Grafana Cloud's Kubernetes Monitoring app expects: Alloy collectors, kube-state-metrics and node-exporter, with **allow lists** that keep only the metrics its dashboards use. That's what keeps a cluster under the free tier's series limit; a full scrape of two nodes would already be near it ([ADR-0021](../../docs/decisions/0021-grafana-cloud-for-monitoring.md)). The Prometheus operator's CRDs (no operator, just the types) let Argo CD and LiteLLM be scraped through `ServiceMonitor`s and let alert rules live in Git as `PrometheusRule`s.
**Questions:**
- `k8s-monitoring` chart version (default: the newest release in `helm search repo grafana/k8s-monitoring --versions` after `helm repo add grafana https://grafana.github.io/helm-charts`, checked against `https://github.com/grafana/k8s-monitoring-helm/releases`). The playbook was written against the `4.6.0` values layout (destinations, features, `collectors` with presets).
- `prometheus-operator-crds` chart version (default: the newest at `https://github.com/prometheus-community/helm-charts/releases`; written against `32.0.2`; the `32.0.3` tag exists on GitHub but wasn't in the Helm repo when this ran).
- Pod logs and Kubernetes events too? Default **yes**: they're the cheapest way to answer "what happened at 3 a.m.", the free tier's 50 GB is far more than this lab writes, and the SRE agents in playbook 07 need them.
- Cluster name in Grafana Cloud. Default `homelab` (every series gets `cluster="homelab"`; the `LabSilent` rule in step 6 depends on it).

**Actions:**
- `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`. Read the pinned `k8s-monitoring` chart's values (`helm show values grafana/k8s-monitoring --version <pinned>`), its `docs/examples/` for `auth/external-secrets` and `destinations/prometheus-rules`, and `docs/Features.md`, for the exact keys in that version. Then write `platform/monitoring/chart-values.yaml`:
  - `cluster.name: homelab`.
  - **Destinations**, with credentials from the Secret `grafana-cloud` (step 3; `secret.create: false`, `auth.type: basic`, `usernameKey`/`passwordKey`): `grafana-cloud-metrics` (`type: prometheus`, the remote write URL from *Before you start*, username key `metrics-username`, password key `token`) and `grafana-cloud-logs` (`type: loki`, the Loki push URL ending in `/loki/api/v1/push`, username key `logs-username`, password key `token`). Leave Alloy's rule sync off: CI owns the rules (step 5, [ADR-0026](../../docs/decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md)). If the chart's values have a `rules:` block, set `rules.enabled: false`.
  - **Features:** `clusterMetrics.enabled: true` (kubelet, cAdvisor, with the default allow lists left on; the control-plane parts off, as k3s doesn't expose them), `clusterEvents.enabled: true`, `podLogsViaLoki.enabled: true` (reads `/var/log/pods` on each node), `prometheusOperatorObjects.enabled: true` (picks up `ServiceMonitor`s). Everything else off, including cost metrics (OpenCost is another pod and many series).
  - **Telemetry services:** `kube-state-metrics.deploy: true`, `node-exporter.deploy: true`.
  - **Collectors:** `alloy-metrics` with presets `[small, clustered, statefulset]` and one replica; `alloy-logs` with `[filesystem-log-reader, daemonset]`; `alloy-singleton` with `[deployment]` and one replica (events and rule sync must run exactly once). Assign each feature to its collector.
  - **Scrape interval:** `global.scrapeInterval: 60s` (Grafana Cloud's free tier counts series, not samples, but 60 s halves the network and Alloy's work compared with 30 s, and is plenty for a lab).
  - **Resources** as a starting point, corrected in step 9. Memory requests / limits: `alloy-metrics` 160Mi / 512Mi; `alloy-logs` 64Mi / 256Mi (per node); `alloy-singleton` 64Mi / 256Mi; the Alloy operator 32Mi / 128Mi; kube-state-metrics 32Mi / 128Mi; node-exporter 16Mi / 64Mi (per node). CPU requests small (10m to 50m), **no CPU limits** (same rule as playbook 04).
- Pin both charts in `bootstrap/versions.env`: `K8S_MONITORING_CHART_VERSION=<pinned>` and `PROM_OPERATOR_CRDS_CHART_VERSION=<pinned>` (CI uses them in step 4; the apps' `targetRevision`s must match).

**Verify:** `helm template monitoring grafana/k8s-monitoring --version <pinned> -n monitoring -f platform/monitoring/chart-values.yaml > /tmp/monitoring.yaml` succeeds; `grep -c 'mimir.rules.kubernetes' /tmp/monitoring.yaml` is `0` (Alloy rule sync is off; CI owns rules); `grep -E '^kind:' /tmp/monitoring.yaml | sort | uniq -c` shows the Alloy collectors, a kube-state-metrics Deployment and a node-exporter DaemonSet; `grep -n 'glc_' /tmp/monitoring.yaml` finds nothing (no token in Git); `helm template crds prometheus-community/prometheus-operator-crds --version <pinned> | grep -c '^kind: CustomResourceDefinition'` is at least 10.
**Record:** Draft `docs/domains/platform/reference-monitoring.md`: what runs in the cluster and what in Grafana Cloud, versions, features on and off and why, the endpoints (URLs, not credentials), the resource table (finished in step 9), and the CI rule-sync path (ADR-0026).

### 3. The Grafana Cloud credentials in SOPS
**Why:** The Alloy token can write metrics, logs and alert rules into your stack. It goes into a SOPS file that you fill in; the agent writes everything around it ([ADR-0020](../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md)). The instance IDs aren't really secret, but they go into the same Secret so the chart reads all credentials from one place.
**Actions:**
- `platform/monitoring/`: `namespace.yaml` (`monitoring`); `secret.enc.yaml`, a Secret `grafana-cloud` with `metrics-username: REPLACE_ME`, `logs-username: REPLACE_ME`, `token: REPLACE_ME`, encrypted in place with `sops encrypt -i` (the placeholders aren't secrets, so the agent may write them); `secret-generator.yaml` (KSOPS, as in `platform/sops-canary`); `kustomization.yaml` with the namespace and the generator.
- 🧑 In **your own terminal** (a second `ssh homelab-gitops.devpod`): `EDITOR=nano sops edit platform/monitoring/secret.enc.yaml`. Don't create a branch here; the agent already did, and both shells share the folder. Move to the value with the arrow keys **before pasting**; quote numeric values (`metrics-username: "3720973"`, `logs-username: "..."`) because bare numbers fail with `expected string`. Replace the three `REPLACE_ME` values with the two instance IDs and the `glc_...` token from the password manager (right-click pastes in the terminal), save (Ctrl+O, Enter), exit (Ctrl+X). After saving, `head -3 platform/monitoring/secret.enc.yaml` shows `apiVersion: v1` first (a paste at the wrong cursor would turn the key into a new YAML key), and `grep -c 'glc_' platform/monitoring/secret.enc.yaml` is `0` (no plaintext token). Tell the agent "done"; it makes a normal commit, no amend and no force-push.

**Verify:** `scripts/check-secrets.sh` passes; `grep -c 'ENC\[' platform/monitoring/secret.enc.yaml` is `3`, and `git diff --stat` shows the file changed after your edit (the agent can't see whether the values are real: an encrypted `REPLACE_ME` looks like any other value; step 4 checks the sizes).
**Record:** `reference-monitoring.md`: what's in `grafana-cloud`, what the token may do (its scopes), how to rotate it (new token in grafana.com, `sops edit`, PR, then delete the old token). The CI rules token is separate and lives in the repo secret (step 5).

### 4. Deliver monitoring through Argo CD
**Why:** From playbook 04 on, nothing reaches the cluster except through a merged PR. Two apps: the CRDs first (no pods; Argo CD needs the types before anything uses them), then `monitoring` with three sources: the chart, its values from this repo, and the `platform/monitoring` folder (namespace, decrypted Secret, later the rules).
**Actions:**
- `bootstrap/project.yaml`: add `https://grafana.github.io/helm-charts` and `https://prometheus-community.github.io/helm-charts` to `sourceRepos`. `bootstrap/` is applied by `install.sh`, not by Argo CD, so the agent reruns `bootstrap/install.sh` after this merge.
- `apps/prometheus-operator-crds.yaml`: the chart at `<PROM_OPERATOR_CRDS_CHART_VERSION>`, destination namespace `monitoring`, automated with `selfHeal: true` and **`prune: false`** (deleting a CRD deletes every object of that type), `syncOptions: [ServerSideApply=true, CreateNamespace=true]` (the CRDs are too big for client-side apply), and the annotation `argocd.argoproj.io/sync-wave: "-1"` so it syncs before the others.
- `apps/monitoring.yaml`: Application `monitoring`, project `platform`, destination namespace `monitoring`. Sources: the chart `k8s-monitoring` from `https://grafana.github.io/helm-charts` at `targetRevision: <K8S_MONITORING_CHART_VERSION>` with `helm.releaseName: monitoring` and `helm.valueFiles: [$values/platform/monitoring/chart-values.yaml]`; this repo at `main` with `ref: values`; this repo at `main` with `path: platform/monitoring`. Automated sync, `prune: true`, `selfHeal: true`; `syncOptions: [ServerSideApply=true]`.
- `scripts/check-versions.sh`: also check both new pins against the `targetRevision`s in `apps/prometheus-operator-crds.yaml` and `apps/monitoring.yaml`.
- `.github/workflows/ci.yml`: render the `k8s-monitoring` chart like Argo CD (`helm template` with the pinned version and `chart-values.yaml`) and pipe it into `kubeconform` with the same flags as Argo CD's render.
- PR, `ci` green, 🧑 squash-merge. Then `git checkout main && git pull` and `bootstrap/install.sh` (applies the project change; Helm reports no change to Argo CD). Refresh `root`. **Until `install.sh` reruns, Argo CD shows `InvalidSpecError ... not permitted in project 'platform'` on the new apps; that's expected, not a failure.**

The first sync takes a few minutes: the Alloy operator starts, then creates the collectors from their custom resources. Pods in `ContainerCreating` for a while are normal; read `kubectl -n monitoring get events --sort-by=.lastTimestamp | tail -20` before calling anything stuck.

**Verify:** `kubectl -n argocd get applications` shows `prometheus-operator-crds` and `monitoring` `Synced` and `Healthy`; `kubectl get crd prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com` finds both; `kubectl -n monitoring get pods -o wide` shows everything `Running` (node-exporter and `alloy-logs` once per node); `kubectl -n monitoring describe secret grafana-cloud` shows three keys, none of exactly 10 bytes (a leftover `REPLACE_ME`); `kubectl -n monitoring logs statefulset/monitoring-alloy-metrics --tail=50` (the real name: `kubectl -n monitoring get statefulsets`) shows no `401`, `403` or `err-mimir-max-series-per-user`; Alloy's own view: `kubectl -n monitoring port-forward statefulset/<alloy-metrics> 12345 >/dev/null &`, then `curl -s localhost:12345/api/v0/web/components | jq -r '.[] | select(.health.state != "healthy") | .localID'` prints nothing (every component healthy); stop it with `kill %1`. 🧑 In Grafana Cloud: **Explore** with the Prometheus data source, `count(up{cluster="homelab"})` is above 5; **Kubernetes Monitoring** (Observability → Kubernetes) shows the `homelab` cluster with both nodes; Explore with Loki, `{cluster="homelab", namespace="argocd"}` shows Argo CD's logs. `kubectl top pods -n monitoring` adds up to under 0.6 GiB.
**Record:** Journal: memory per pod and per node after; what you saw in Grafana Cloud.

### 5. Series budget, Slack, and the alert path end to end 🧑
**Why:** The free tier stops accepting new series at its limit, so check the count before adding more scrapes. And an alert path nobody has tested is decoration: this step sets up Slack in Grafana Cloud and proves that a rule written in Git ends as a message in `#homelab-alerts`.
**Actions:**
- 🧑 **Series:** in Explore, pick the `grafana-usage` data source and query `grafanacloud_instance_active_series` (or open **Administration → Usage insights / Billing**). Cross-check with the Prometheus data source: `count({cluster="homelab"})` (not `count(up{...})`, which counts one series per target). Tell the agent the number. Budget: below 5,000 now, so the gateway, Argo CD and later playbooks fit under 10,000 with room for spikes (a pod restart briefly doubles its series). If it's above, the agent reads the chart's `metricsTuning` options and drops the largest metric families (`topk(10, count by (__name__) ({cluster="homelab"}))` in Explore, from you) before going on.
- 🧑 **Slack:** in your stack's Grafana (`https://<stack>.grafana.net`), **Alerting → Notification configuration** (tabs along the top). This stack has **no Alertmanager drop-down**; the only Alertmanager is Grafana's. Under **Contact points → New contact point**, integration **Slack**, name `slack`, Recipient `#homelab-alerts` (or put the webhook URL in **Webhook URL** and leave **Token** empty); **Test** and save. Under **Notification policies**, default policy → contact point `slack`, group by `alertname` and `namespace`, repeat interval 12h. Add a notification template so the title is readable on a phone: `{{ .CommonLabels.alertname }} {{ .CommonLabels.node }}{{ .CommonLabels.namespace }}`, with the `summary` annotation in the body; set it as the contact point's title. Skip a nested `severity="info"` policy (it needs a mute timing). Tell the agent "done".
- Agent: the CI path. Add `.github/workflows/alert-rules.yaml` (or update the one in the repo): on PR, `mimirtool rules lint` and `mimirtool rules check`; on push to `main`, extract every `PrometheusRule` `.spec` with `yq` into **one** file with top-level `namespace: homelab` (`mimirtool` rejects repeated namespaces), run `mimirtool rules diff` first (against the same `homelab` scope) and fail on deletes outside `homelab`, then `mimirtool rules sync --concurrency 1 --namespaces=homelab` against `https://<stack>.grafana.net/api/convert/` with header `X-Grafana-Alerting-Datasource-UID=grafanacloud-prom`. The token is the repo secret `GRAFANA_RULES_TOKEN`, a service account `homelab-rules-sync` with Alerting rules reader/writer + set provisioning status, Datasources reader, Folders creator/reader/writer. Set an explicit **1-year expiry** and a calendar reminder; `401 "Expired API key"` means rotate and re-run. Never commit the token. ([ADR-0026](../../docs/decisions/0026-grafana-managed-alert-rules-synced-from-git-by-ci.md))
- Agent: `platform/monitoring/rules.yaml` with one `PrometheusRule` `lab` and two groups: `lab` with `LabSilent` (the dead man's switch; step 6 adds the rest) and `playbook-test` with `PlaybookTest` (`expr: vector(1)`, `for: 0m`, `labels: {severity: warning}`, `annotations: {summary: "Test alert from playbook 05, synced from Git"}`). Add it to `kustomization.yaml`. PR, `ci` green, 🧑 squash-merge.
- 🧑 After the merge, the `alert-rules` workflow runs; within a few minutes **Alerting → Alert rules** shows the `homelab` folder with `LabSilent` (`Normal`) and `PlaybookTest` (`Firing`), both **Provisioned** (read-only in the UI), and the Slack message arrives. Say "done". Agent: remove the `playbook-test` group in a second PR (keep `rules.yaml` for step 6); 🧑 merge; the rule disappears from Grafana Cloud and Slack gets a "resolved".

**Verify:** The series count is recorded and under budget; the Slack message arrived and resolved; the rules appeared and disappeared in Grafana Cloud only through Git; `LabSilent` is `Normal` (not `NoData`).
**Record:** `reference-monitoring.md`: the series budget and how to check it, the CI workflow and token (never the value), the Slack contact point, template and policies (written down, since they're set in the UI), how to send a test alert. Journal: series count, how long Git → Slack took.

> **Run follow-up (token expiry):** the rules token expired after less than a day on the first run (Grafana's default short expiry) and every `alert-rules` run failed with `401 "Expired API key"` while rules silently stopped syncing. Set an explicit **1-year expiry** and a calendar reminder. The Alloy token and the rules token are different: the Alloy token writes metrics/logs; the rules token is the CI service account.

### 6. Rules for this lab: the lab going silent, Argo CD, swap, disks
**Why:** The most important alert for a lab watched from outside is the one a self-hosted stack can't send: **the lab stopped talking**. Grafana Cloud's ruler evaluates `LabSilent` (added in step 5) while the cluster is dead. Then three things particular to this lab: an Argo CD app that stays out of sync or unhealthy (Git no longer describes the cluster), sustained swapping (zram hides memory pressure until it doesn't, [ADR-0016](../../docs/decisions/0016-zram-swap-on-k3s-nodes.md)), and a node's disk filling up (local-path volumes, etcd and images share the 60 GB).
**Actions:**
- Argo CD metrics: in `bootstrap/argocd/values.yaml`, enable the **ServiceMonitor for `controller` only** (`metrics.enabled` can stay on for `server` and `repoServer`; their ServiceMonitors stay off). Add `metricRelabelings` to the controller ServiceMonitor keeping `argocd_app_info`, `argocd_app_sync_total`, `argocd_app_k8s_request_total`, `argocd_cluster_info` and `up`. The server and repo-server Go/gRPC/process metrics added about 3,250 series for no alert value. (The CRDs from step 4 make `ServiceMonitor` a valid type now.)
- In `rules.yaml`, group `lab` (the `LabSilent` rule is already there from step 5):
  - `ArgoCDAppOutOfSync`: `argocd_app_info{sync_status!="Synced"} == 1` for 30m, warning.
  - `ArgoCDAppUnhealthy`: `argocd_app_info{health_status!~"Healthy|Progressing"} == 1` for 15m, warning.
  - `NodeSwapping`: `rate(node_vmstat_pswpin[10m]) > 100` for 30m (pages per second swapped in), warning: "steady swapping means this node needs less load or more RAM". `node_vmstat_pswpin` may not be on the chart's node-exporter allow list; add it to the allow list if it's missing (one series per node).
  - `NodeDiskFilling`: `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.15` for 15m, warning (check these metrics are on the allow list too).
  - `NodeNotReady`: `kube_node_status_condition{condition="Ready", status="true", cluster="homelab"} == 0` for 5m, critical: "a k3s node has been NotReady for 5 minutes". This replaces Grafana's stock node alert, which we don't install.
  - `PodCrashLooping`: `increase(kube_pod_container_status_restarts_total{cluster="homelab"}[15m]) > 3` for 15m, warning: "a container has restarted more than 3 times in 15 minutes".
- Don't install Grafana's recommended Kubernetes Monitoring alert rules: on this stack they were skipped (series budget, duplicates), and the two we wanted (`NodeNotReady`, `PodCrashLooping`) are in Git above. If you want another stock rule, add it to `rules.yaml` deliberately.
- PR, `ci` green, 🧑 squash-merge, `git checkout main && git pull`.

**Verify:** `argocd` stays `Synced`/`Healthy` after its values change (only the controller metrics Service and `ServiceMonitor` are new); 🧑 in Explore, `up{cluster="homelab", namespace="argocd"}` has **one** series (controller only), all `1`, and `argocd_app_info` lists every application; the `lab` group shows seven rules in Grafana Cloud, all `Normal` (`LabSilent` included: it only fires when data stops).
**Record:** `reference-monitoring.md`: the lab rules and why each exists, and why Grafana's recommended rules are not installed.

### 7. The gateway on the cluster
**Why:** The gateway is the one endpoint every agent calls ([ADR-0008](../../docs/decisions/0008-vendor-neutral-ai-stack.md)). On the laptop it costs 400 MB of an 8 GB machine and is gone when the laptop sleeps; Hermes (06), the SRE agents (07) and the factory (08) run on the cluster and need it there. It's deployed as plain manifests (LiteLLM's Helm chart is built around a database this lab doesn't need yet), with the config in Git and the keys in SOPS ([ADR-0022](../../docs/decisions/0022-llm-gateway-on-k3s.md)).
**Questions:**
- LiteLLM version (default: the newest `v1.x.y` release at `https://github.com/BerriAI/litellm/releases` that exists as a `litellm/litellm` image tag on Docker Hub; written against `v1.106.6`; the laptop runs `v1.106.2`).
- Same master key as the laptop gateway? Default **yes**: every container's `LLM_GATEWAY_KEY` keeps working, and the switch after the session is only a URL. A new key would mean a new Windows variable and recreating every container.
- How the laptop reaches it. Default **plain HTTP through Traefik** at `llm.<k3s-01-ip>.nip.io`, on the home LAN only. HTTPS with Traefik's self-signed certificate would make every client (OpenCode, Python tools) reject the connection; a lab CA comes with the DNS question. Inside the cluster, clients use `http://litellm.llm-gateway.svc:4000`.
- The `local` alias (Ollama on the laptop). Default **leave it out**: Ollama isn't installed, and a cluster pod can't reach `host.docker.internal`.

**Actions:**
- `platform/llm-gateway/`:
  - `namespace.yaml` (`llm-gateway`).
  - `config.yaml`: the aliases from `workstation/gateway/config.yaml` (same models, same `max_budget`/`budget_duration`, `drop_params`), without `local`, plus `litellm_settings.callbacks: ["langfuse_otel", "prometheus"]` (traces to Langfuse, metrics on `/metrics`). No secret in it: `master_key: os.environ/LITELLM_MASTER_KEY`.
  - `kustomization.yaml` with a `configMapGenerator` for `config.yaml` (the name gets a content hash, so a config change rolls the pod), the other files as resources, and the KSOPS generator.
  - `secret.enc.yaml`: Secret `llm-gateway` with `OPENROUTER_API_KEY`, `LITELLM_MASTER_KEY`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, all `REPLACE_ME`, encrypted in place; `secret-generator.yaml` (KSOPS).
  - `deployment.yaml`: one replica, image `litellm/litellm:<pinned>`, args `--config /app/config.yaml --port 4000 --num_workers 1`; `envFrom` the Secret; env `LANGFUSE_OTEL_HOST=https://cloud.langfuse.com` (the EU region; LiteLLM defaults to the US one); the ConfigMap mounted at `/app/config.yaml` with `subPath`; readiness probe `GET /health/readiness`, liveness probe `GET /health/liveliness` (LiteLLM's spelling), both on 4000, liveness with `initialDelaySeconds: 60` (the image takes a while to start); resources: requests `50m`/`384Mi`, limit memory `1Gi`.
  - `service.yaml`: `litellm`, port 4000 named `http`.
  - `ingress.yaml`: host `llm.<k3s-01-ip>.nip.io`, `ingressClassName: traefik`, annotation `traefik.ingress.kubernetes.io/router.entrypoints: web` (HTTP).
  - `servicemonitor.yaml`: scrape `/metrics/` on the `http` port every 60 s (check the path on the running pod: `kubectl -n llm-gateway exec deploy/litellm -- curl -s -o /dev/null -w '%{http_code}' localhost:4000/metrics/`). Keep only the metric families the dashboard in step 8 uses (`metricRelabelings` with `action: keep`): LiteLLM labels by model, key and team, and every label value is a new series against the free tier's limit.
- `apps/llm-gateway.yaml`: Application `llm-gateway`, project `platform`, `path: platform/llm-gateway`, automated with prune and self-heal.
- 🧑 In **your own terminal** (a second `ssh homelab-gitops.devpod`), on the agent's branch: in PowerShell, open the laptop gateway's keys in Notepad (`notepad "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\gateway\.env"`, close without saving afterwards). In the container shell, `EDITOR=nano sops edit platform/llm-gateway/secret.enc.yaml` and replace the four `REPLACE_ME` values: `OPENROUTER_API_KEY` and `LITELLM_MASTER_KEY` from that `.env`, the two Langfuse keys from the password manager. Move to the value with the arrow keys **before pasting**. Save (Ctrl+O, Enter), exit (Ctrl+X); then `head -3 platform/llm-gateway/secret.enc.yaml` shows `apiVersion: v1` first and `grep -c 'sk-or' platform/llm-gateway/secret.enc.yaml` is `0` (no plaintext key). Tell the agent "done"; it makes a normal commit (no amend, no force-push).
- PR, `ci` green, 🧑 squash-merge, `git checkout main && git pull`, refresh `root`.

**Verify:** `llm-gateway` is `Synced`/`Healthy`; `kubectl -n llm-gateway describe secret llm-gateway` shows four keys, none of exactly 10 bytes (a leftover `REPLACE_ME`); `kubectl -n llm-gateway logs deploy/litellm | tail -20` shows the proxy started with no `langfuse` error; from the container, `curl -s -H "Authorization: Bearer $LLM_GATEWAY_KEY" http://llm.<k3s-01-ip>.nip.io/v1/models | jq -r '.data[].id'` lists `fast`, `code`, `reason`; a real call works: `curl -s http://llm.<k3s-01-ip>.nip.io/v1/chat/completions -H "Authorization: Bearer $LLM_GATEWAY_KEY" -H 'Content-Type: application/json' -d '{"model":"fast","max_tokens":200,"messages":[{"role":"user","content":"Reply with the word ok."}]}' | jq -r '.choices[0].message.content'`; 🧑 in Explore, `up{cluster="homelab", namespace="llm-gateway"}` is `1`; `kubectl top pod -n llm-gateway` shows its memory. Use `$LLM_GATEWAY_KEY` by name only; never echo it.
**Record:** Update `docs/domains/ai-stack/reference-gateway.md`: the cluster endpoints (in-cluster and LAN), where config and keys live now, the version, memory, and that the laptop Compose file is the fallback. Journal: memory, start-up time.

### 8. Traces in Langfuse, a gateway dashboard and alert 🧑
**Why:** The gateway is now the place to see what agents cost and how they behave. Langfuse shows each call (prompt, model, tokens, cost); Grafana Cloud shows rates, errors and latency over time, and pages you when the gateway is down.
**Actions:**
- 🧑 In Langfuse Cloud (EU), open the project's **Traces**: the `fast` call from step 7 is there with its model, token counts and cost. Tell the agent "done" (or what's missing).
- Agent: a `LiteLLMDown` rule in the `lab` group (`up{cluster="homelab", namespace="llm-gateway"} == 0 or absent(up{cluster="homelab", namespace="llm-gateway"})`, for 5m, critical). And the dashboard: LiteLLM publishes one in its repo (`cookbook/litellm_proxy_server/grafana_dashboard/`); copy it to `platform/llm-gateway/dashboard.json` (kept in Git as the record; it's not deployed to the cluster), check its metric names against `/metrics/` on the pinned version and against the `keep` list from step 7. PR, `ci` green, 🧑 squash-merge.
- 🧑 In Grafana Cloud, **Dashboards → New → Import**, paste `dashboard.json`, pick the Prometheus data source, save it in a folder `homelab`.

**Verify:** The trace is in Langfuse; the dashboard shows the step 7 calls; `LiteLLMDown` is in the `lab` group in Grafana Cloud, `Normal`; the series count from step 5 is still under 5,000 (🧑).
**Record:** `reference-gateway.md`: where traces and the dashboard are, the Langfuse limit (50k units a month) and the Grafana Cloud series budget, and how to check both.

### 9. Right-size with real numbers
**Why:** Requests set in step 2 and in playbook 04 were guesses. Grafana Cloud has now recorded every container's memory for the whole run, including Argo CD syncing several charts. Requests close to real use leave room for playbooks 06 to 08; limits well above it keep a spike from killing a pod. This also closes the playbook 04 follow-up (the controller requested 256 Mi and used about 36 Mi).
**Actions:**
- 🧑 In Explore (Prometheus data source, **Table** view, range "Last 6 hours", instant query), run `max by (namespace, pod, container) (max_over_time(container_memory_working_set_bytes{cluster="homelab", container!="", namespace=~"argocd|monitoring|llm-gateway"}[6h]))`, then **Inspect → Data → Download CSV**, and save it as `.runs/peak-memory.csv` in the repo folder on Windows. Tell the agent.
- Agent: read the CSV, show a table with each container's peak and its current request and limit.
- Rule: request = peak × 1.25, rounded up to 16 Mi; limit = at least 2 × the request and at least the peak + 128 Mi; keep the Argo CD repo server's limit at 512 Mi or more (rendering charts spikes) and the gateway's at 1 Gi. Propose the new values; ask before applying.
- Change `bootstrap/argocd/values.yaml`, `platform/monitoring/chart-values.yaml` and `platform/llm-gateway/deployment.yaml`. PR, `ci` green, 🧑 squash-merge, `git checkout main && git pull`.

**Verify:** All apps `Synced`/`Healthy`; no pod in these namespaces restarted with `OOMKilled` in the next 10 minutes (`kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {.status.containerStatuses[*].lastState.terminated.reason}{"\n"}{end}' | grep OOM` finds nothing); `kubectl describe nodes | grep -A8 'Allocated resources'` shows more free requestable memory than step 1 would predict.
**Record:** `reference-argocd.md` and `reference-monitoring.md`: final resources with the measured peaks; journal: the before/after table per node, and what's left for playbooks 06 to 08.

### 10. Drills
**Why:** Alerts are only trusted after they've fired for a real reason. These drills break things on purpose while you're watching.
**Actions:**
- **Gateway pod lost:** `kubectl -n llm-gateway delete pod -l app=litellm` (the label you used). Time until `/v1/models` answers again. (OpenCode keeps working: it still uses the laptop gateway during this session.)
- **Node down:** `kubectl drain k3s-02 --ignore-daemonsets --delete-emptydir-data`, 🧑 shut `k3s-02` down from Proxmox (**Shutdown**, not reboot), wait 15 minutes. Watch Slack (our `NodeNotReady` rule in the `lab` group, added because the stock rules were skipped, after its `for:` time; note how long), and in Grafana Cloud's Kubernetes view see the node go. Note which pods can't move: a pod with a `local-path` volume stays `Pending` until its node is back, because the volume lives on that node. If `alloy-metrics` was on `k3s-02`, there's a gap in the metrics until it reschedules: the collector's single replica is the weak spot, and the reason `LabSilent` waits 15 minutes. 🧑 Start `k3s-02` again, `kubectl uncordon k3s-02`.
- **Lab silent:** the real test is the next time the whole lab is off (planned Proxmox maintenance, a power cut): `LabSilent` should page Slack after about 15 minutes, and resolve when the lab is back. Don't fake it here (stopping Alloy fights Argo CD's self-heal); write it into the runbook as "first real occurrence = the test", and record it in the journal when it happens.

**Verify:** Each drill that ran ends with every application `Synced`/`Healthy` and, 🧑 in Grafana Cloud, no lab alert firing.
**Record:** Journal: times for each drill, which alert fired and after how long, which pods were stuck while `k3s-02` was down. Update `docs/domains/platform/runbook-alerts.md`: what each lab alert means and the first three things to check, `LabSilent` first (is the lab powered, is the network up, are the Alloy pods running, is the token expired or revoked: Alloy logs say `401`).

### 11. Prepare the switch to the cluster gateway
**Why:** The switch itself happens after the session, because OpenCode is using the laptop gateway right now. This step writes down everything you'll need, including the way back for when the cluster is down and an agent is needed to fix it.
**Actions:**
- Don't change `LLM_GATEWAY_URL` yet: it stays `http://host.docker.internal:4000` until the after-session switch; the laptop gateway is still the one OpenCode uses.
- In the `workstation` repo (clone it to `/tmp`, branch, PR, as in playbook 04 step 10): `gateway/README.md` (or a section in the repo README) says the Compose gateway is now the **fallback** and how to use it: `docker compose ... up -d` from PowerShell, then point `LLM_GATEWAY_URL` back at `http://host.docker.internal:4000` and recreate the container. Keep `gateway/config.yaml` and the cluster's `platform/llm-gateway/config.yaml` in step: same aliases; add a line to both saying the other exists.
- Write `docs/domains/ai-stack/runbook-gateway-fallback.md`: when (cluster or `k3s-*` down, `llm.<ip>.nip.io` doesn't answer, nip.io down), the steps there and back, and how to check which one a container is using (`echo $LLM_GATEWAY_URL`).

**Verify:** The `workstation` PR's checks pass (🧑 merge); the runbook is in the handbook branch.
**Record:** Journal.

### 12. Finish
**Actions:** Close the journal entry (what broke, memory per pod and per node before and after, the series count, drill times, how long a merge takes to reach the cluster and Git takes to reach Slack). Fill in `docs/domains/platform/index.md` (monitoring added to the diagram, links to `reference-monitoring` and `runbook-alerts`) and `docs/domains/ai-stack/index.md` (the gateway runs on k3s now). ADR-0021 (accepted, amended by ADR-0026) and ADR-0022 (accepted): ask whether they still hold. Open questions: close "Observability stack" with ADR-0021 (accepted, amended by ADR-0026). Update the playbook catalog (05 done, with the date), the decision log (add ADR-0026) and `reference-monitoring.md`. Remind the human to export the session and check it with `grep -cE 'sk-or-v1-[0-9a-f]{20}|sk-lf-[0-9a-f-]{20}|homelab-infra=[0-9a-f]{8}-|K3S_TOKEN=[0-9a-f]{16}|client-key-data: [A-Za-z0-9]|BEGIN OPENSSH PRIVATE KEY-----.{0,4}b3Bl|AGE-SECRET-KEY-1[0-9A-Z]{20}|glc_[A-Za-z0-9+/=]{20}|hooks\.slack\.com/services/T[A-Z0-9]+/'` before sharing (the last two are the Grafana Cloud token and the Slack webhook). Open the handbook PR.

**After the session 🧑** (in this order):
1. Exit OpenCode. In **PowerShell**, point new containers at the cluster gateway: `setx LLM_GATEWAY_URL "http://llm.<k3s-01-ip>.nip.io"`. Close PowerShell and open a new window (`setx` only affects new windows).
2. Stop the laptop gateway: `docker stop llm-gateway`. (It's the fallback now; `docker start llm-gateway` brings it back.)
3. Recreate the container so it picks up the new URL: `devpod up "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops" --recreate --ide none`, then `ssh homelab-gitops.devpod` and `gh auth login` again.
4. There: `echo $LLM_GATEWAY_URL` shows the cluster address, `curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $LLM_GATEWAY_KEY" "$LLM_GATEWAY_URL/v1/models"` prints `200`, and `opencode` answers a question. That's the first agent session through the cluster; its trace shows up in Langfuse.
5. Other containers (`handbook`, `homelab-infra`) pick up the new URL the next time they're recreated (`devpod up ... --recreate`). Until then they still point at the stopped laptop gateway: recreate before using OpenCode in them.

## Part B (optional): the k3s token into SOPS
The playbook 04 follow-up. `homelab-infra/.env` holds the k3s cluster token in plain text on the laptop; without it, etcd snapshots can't be restored. Encrypted with the lab age key, it's backed up in Git like every other secret ([ADR-0020](../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md)). Run it after the switch above, in the `homelab-infra` container: it's also the first real work through the cluster gateway.

**Before you start 🧑:** the `homelab-infra` dev container needs the age key mount from playbook 04 step 10. In PowerShell, add it to that repo's `.devcontainer/devcontainer.json` exactly as in playbook 04's *Before you start* (the `$j.mounts` and `$j.containerEnv` lines, with `$r` set to the `homelab-infra` folder), stop the `homelab-gitops` container (`devpod stop homelab-gitops`), then `devpod up $r --recreate --ide none` and open a shell (`vsc-homelab-infra` in the `docker ps` line). Check `sops --version` and `echo $SOPS_AGE_KEY_FILE`. If `sops` is missing, the repo's Dockerfile is older than the workstation template: copy the `sops` and `age` lines from `workstation/devcontainer/Dockerfile` into it and recreate again. Then `opencode`:
> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run Part B of `/knowledge/handbook/playbooks/05-monitoring-gateway`.

**B1. Encrypt and load.** Agent, on a branch: list the variables in `.env` by name only (`cut -d= -f1 .env`); add `.sops.yaml` to `homelab-infra` with the same age public key as `homelab-gitops/.sops.yaml` and a rule for `path_regex: .*\.enc\.env$` (dotenv files: every value encrypted); write `k3s/load-secrets.sh`, sourced by `install.sh` instead of `.env`, which loads `k3s/secrets.enc.env` with `set -a; source <(sops decrypt k3s/secrets.enc.env); set +a`, and with `--check` prints only the variable names it loaded and `ok`. Never print a value. 🧑 In **your own terminal** in the same container: `sops encrypt --input-type dotenv --output-type dotenv .env > k3s/secrets.enc.env`, then `cmp -s <(sops decrypt k3s/secrets.enc.env) .env && echo same || echo DIFFERENT` prints `same`. Agent: `k3s/load-secrets.sh --check` lists `K3S_TOKEN` and `ok`; `grep -c 'ENC\[' k3s/secrets.enc.env` equals the number of variables; `gitleaks detect` finds nothing; commit, PR, `ci` green, 🧑 squash-merge, `git checkout main && git pull`.
**B2. Retire the plain file.** 🧑 Make sure the k3s token is in the password manager (from playbook 03), then rename `.env` to `.env.old` in Windows Explorer and keep it a week before deleting it. Agent: `k3s/load-secrets.sh --check` still passes without `.env`. The next real `install.sh` run (an upgrade or a new node) is the full test; mark that **untested** until then.
**Record:** Update `docs/domains/k3s/reference-k3s.md` (where the token lives now), `docs/domains/platform/howto-secrets-sops.md` (SOPS for dotenv files outside Argo CD), and the open question "Move `homelab-infra/.env` into SOPS" (closed, with ADR-0020). Journal.

## When it's done
- Code: `homelab-gitops` (`platform/monitoring` with the lab rules, `platform/llm-gateway`, three new apps, right-sized values, CI checks for the new chart pins), the `workstation` gateway marked as the fallback, and, with Part B, `homelab-infra` reading the k3s token from SOPS.
- Grafana Cloud: the `homelab` stack receiving metrics, logs and events; the Slack contact point, template and policies; the gateway dashboard; all written down in `reference-monitoring.md`.
- Docs updated: `docs/domains/platform/` (index, reference-monitoring, runbook-alerts, reference-argocd), `docs/domains/ai-stack/` (index, reference-gateway, runbook-gateway-fallback), ADRs 0021, 0022 and 0026, open questions, playbook catalog, decision log, journal.
- Next playbook: 06, Hermes on k3s: the gateway's second client, which brings virtual keys per client (and the small database they need).

## Video
Not recorded yet. Good candidates: step 5 ("an alert rule in a pull request, a message in Slack") and the first real `LabSilent` ("my homelab died and the cloud told me").
