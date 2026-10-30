---
type: playbook
title: Monitor the cluster with Grafana Cloud and run the LLM gateway on k3s
description: Sends the cluster's metrics, logs and events to Grafana Cloud's free tier through Grafana Alloy, keeps alert rules in Git and pages Telegram, moves the LiteLLM gateway from the laptop to the cluster with traces to Langfuse Cloud, then right-sizes every app with measured numbers.
domain: platform
tags: [monitoring, grafana-cloud, alloy, prometheus-rules, alerting, litellm, langfuse, opentelemetry, argocd, sops]
status: draft
created: 2026-10-30
updated: 2026-10-30
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
  - ../../docs/domains/platform/reference-argocd.md
  - ../../docs/domains/platform/howto-secrets-sops.md
  - ../../docs/domains/ai-stack/reference-gateway.md
  - ../../docs/domains/k3s/reference-k3s.md
  - ../../docs/open-questions/index.md
blog: candidate
---

# Monitor the cluster with Grafana Cloud and run the LLM gateway on k3s

## What you'll have at the end
The cluster is watched from outside. Grafana Alloy, deployed by Grafana's `k8s-monitoring` chart as one Argo CD app, `monitoring`, collects metrics (kubelet, cAdvisor, kube-state-metrics, node-exporter, Argo CD, the gateway), pod logs and Kubernetes events, and sends them to a Grafana Cloud free-tier stack ([ADR-0021](../../docs/decisions/0021-grafana-cloud-for-monitoring.md)). Storage, dashboards, queries and alerting run in Grafana Cloud, so the lab spends about 0.5 GB on collectors instead of about 0.8 GB on a whole stack, and the alerts keep working when the lab is down: a `LabSilent` rule pages you when the cluster stops sending data.

Alert rules live in Git as `PrometheusRule` objects. Alloy syncs them to Grafana Cloud's ruler, so a new alert is a pull request like everything else. Alerts reach your phone on Telegram.

The LLM gateway moves from the laptop to the cluster as a second app, `llm-gateway`: the same LiteLLM aliases (`fast`, `code`, `reason`), its keys in SOPS, traces to Langfuse Cloud over OpenTelemetry ([ADR-0012](../../docs/decisions/0012-langfuse-cloud-until-capacity.md), [ADR-0022](../../docs/decisions/0022-llm-gateway-on-k3s.md)), and its metrics in Grafana Cloud. The laptop gets about 400 MB back and keeps the old Compose file as a fallback for when the cluster is down.

Finally, every app's memory requests are set from what Grafana Cloud measured during the run, including the Argo CD follow-up from playbook 04. An optional last part moves the k3s token from `homelab-infra/.env` into SOPS.

```
homelab-gitops (main) ── Argo CD (root) ──► apps/prometheus-operator-crds.yaml (CRDs only, no pods)
                                     ├──► apps/monitoring.yaml   ──► namespace monitoring
                                     └──► apps/llm-gateway.yaml  ──► namespace llm-gateway

monitoring:  alloy-metrics ──scrape──► kubelet, cAdvisor, kube-state-metrics, node-exporter,
                                       ServiceMonitors (Argo CD, LiteLLM)
             alloy-logs (per node) ──► pod logs        alloy-singleton ──► events, PrometheusRule sync
                   │ remote write / push (token from SOPS)
                   ▼
Grafana Cloud (free): Prometheus (metrics), Loki (logs), ruler + Alertmanager ──► Telegram
                      Grafana: https://<stack>.grafana.net

llm-gateway: litellm ──► OpenRouter          ──OTel──► Langfuse Cloud (EU)
             in cluster: http://litellm.llm-gateway.svc:4000
             from the laptop: http://llm.<k3s-01-ip>.nip.io   (after the session)
```

What this playbook does not do: scrape the k3s control plane (scheduler, controller manager and etcd run inside the k3s process without metrics endpoints; see the open questions), virtual keys and a database for the gateway (playbook 06, when Hermes becomes the second client), TLS for the gateway on the LAN (it comes with lab DNS and a lab CA), and dashboards or contact points as code (they're set up in the Grafana Cloud UI and written down; Terraform for them is an open question).

## Before you start 🧑
- [ ] Playbook 04 is done: in the `homelab-gitops` container, `kubectl -n argocd get applications` shows `argocd`, `root` and `sops-canary` `Synced` and `Healthy`.
- [ ] The handbook on Windows is on `main` and up to date (it includes this playbook).
- [ ] The laptop gateway is running (`docker ps` in PowerShell shows `llm-gateway`). **It stays running for the whole session**: OpenCode talks to it. The switch to the cluster gateway happens after the session.
- [ ] OpenRouter has credit: the playbook 03 run stalled on a `402` (in-flight credit limit). Check `https://openrouter.ai/settings/credits` and the key's limit.
- [ ] **A Grafana Cloud stack.** Sign up at `https://grafana.com` (free plan), and create a stack in an **EU region** (same reasoning as Langfuse, ADR-0012). Note the stack's Grafana address (`https://<stack>.grafana.net`). Check the current free-tier limits on `https://grafana.com/pricing` (when this was written: 10k active metric series, 50 GB of logs, 14 days of retention); the playbook keeps the series well under the limit.
- [ ] **Its endpoints and a write token.** At `https://grafana.com/orgs/<org>/stacks`, open the stack: under **Prometheus → Details**, note the remote write URL (ends in `/api/prom/push`) and the instance ID (a number, the username); under **Loki → Details**, the URL and its instance ID. Then **Access Policies** (grafana.com → Security): create a policy `homelab-alloy` for this stack with scopes `metrics:write`, `logs:write`, `rules:read` and `rules:write`, and a token for it. Save the token (`glc_...`) and the two instance IDs in the password manager. The URLs aren't secret; tell the agent in step 2.
- [ ] **Langfuse Cloud keys.** At `https://cloud.langfuse.com` (EU region), open or create the project for the lab, then **Settings → API Keys → Create new API key**. Save the public key (`pk-lf-...`) and the secret key (`sk-lf-...`) in the password manager.
- [ ] **A Telegram bot for alerts.** In Telegram, open `@BotFather`, send `/newbot`, pick a name; save the bot token in the password manager. Send any message to your new bot, then open `https://api.telegram.org/bot<token>/getUpdates` in your browser and note `"chat":{"id":...}`. That number is the chat ID. The token goes only into Grafana Cloud's contact point (step 5), never into Git or the agent's terminal.
- [ ] Only one dev container runs at a time (8 GB laptop). Start the `homelab-gitops` container and open a shell, in **PowerShell**:
```powershell
$r = "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops"
devpod up $r --ide none
$c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-homelab-gitops" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
docker exec -it -u vscode -w /workspaces/homelab-gitops $c bash
```
- [ ] In the container: `gh auth status` (if it says not logged in: `gh auth login -h github.com -s repo,workflow`, enter the code on github.com, then click the final green **Authorize**), `git checkout main && git pull`, `kubectl get nodes` (both `Ready`), and `curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $LLM_GATEWAY_KEY" "$LLM_GATEWAY_URL/v1/models"` prints `200` (the laptop gateway answers).

## Kick it off
In the container's terminal:
```bash
opencode
```
> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/05-monitoring-gateway`.

If you're resuming an earlier run, say so: the agent checks each step's Verify first and skips what's done.

**Keep a second terminal for yourself.** Steps 3 and 7 ask you to type secrets with `sops edit`, which the agent must never see. Open a second PowerShell window, set `$c` again with the `docker ps` line above, and run `docker exec -it -u vscode -w /workspaces/homelab-gitops $c bash`. That shell is yours, not the agent's. Both shells share the repo folder.

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
- `prometheus-operator-crds` chart version (default: the newest at `https://github.com/prometheus-community/helm-charts/releases`; written against `32.0.3`).
- Pod logs and Kubernetes events too? Default **yes**: they're the cheapest way to answer "what happened at 3 a.m.", the free tier's 50 GB is far more than this lab writes, and the SRE agents in playbook 07 need them.
- Cluster name in Grafana Cloud. Default `homelab` (every series gets `cluster="homelab"`; the `LabSilent` rule in step 6 depends on it).

**Actions:**
- `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`. Read the pinned `k8s-monitoring` chart's values (`helm show values grafana/k8s-monitoring --version <pinned>`), its `docs/examples/` for `auth/external-secrets` and `destinations/prometheus-rules`, and `docs/Features.md`, for the exact keys in that version. Then write `platform/monitoring/chart-values.yaml`:
  - `cluster.name: homelab`.
  - **Destinations**, with credentials from the Secret `grafana-cloud` (step 3; `secret.create: false`, `auth.type: basic`, `usernameKey`/`passwordKey`): `grafana-cloud-metrics` (`type: prometheus`, the remote write URL from *Before you start*, username key `metrics-username`, password key `token`) and `grafana-cloud-logs` (`type: loki`, the Loki push URL ending in `/loki/api/v1/push`, username key `logs-username`, password key `token`). On the metrics destination, turn on **rule sync**: `rules.enabled: true`, `rules.address` = the remote write URL without `/api/prom/push` (the ruler API lives at the base URL), `rules.collector: alloy-singleton`. If the pinned version has no `rules` key on destinations, add Alloy's `mimir.rules.kubernetes` component through the collector's `extraConfig` instead (`docs/UsingExtraConfig.md`), and record why.
  - **Features:** `clusterMetrics.enabled: true` (kubelet, cAdvisor, with the default allow lists left on; the control-plane parts off, as k3s doesn't expose them), `clusterEvents.enabled: true`, `podLogsViaLoki.enabled: true` (reads `/var/log/pods` on each node), `prometheusOperatorObjects.enabled: true` (picks up `ServiceMonitor`s). Everything else off, including cost metrics (OpenCost is another pod and many series).
  - **Telemetry services:** `kube-state-metrics.deploy: true`, `node-exporter.deploy: true`.
  - **Collectors:** `alloy-metrics` with presets `[small, clustered, statefulset]` and one replica; `alloy-logs` with `[filesystem-log-reader, daemonset]`; `alloy-singleton` with `[deployment]` and one replica (events and rule sync must run exactly once). Assign each feature to its collector.
  - **Scrape interval:** `global.scrapeInterval: 60s` (Grafana Cloud's free tier counts series, not samples, but 60 s halves the network and Alloy's work compared with 30 s, and is plenty for a lab).
  - **Resources** as a starting point, corrected in step 9. Memory requests / limits: `alloy-metrics` 160Mi / 512Mi; `alloy-logs` 64Mi / 256Mi (per node); `alloy-singleton` 64Mi / 256Mi; the Alloy operator 32Mi / 128Mi; kube-state-metrics 32Mi / 128Mi; node-exporter 16Mi / 64Mi (per node). CPU requests small (10m to 50m), **no CPU limits** (same rule as playbook 04).
- Pin both charts in `bootstrap/versions.env`: `K8S_MONITORING_CHART_VERSION=<pinned>` and `PROM_OPERATOR_CRDS_CHART_VERSION=<pinned>` (CI uses them in step 4; the apps' `targetRevision`s must match).

**Verify:** `helm template monitoring grafana/k8s-monitoring --version <pinned> -n monitoring -f platform/monitoring/chart-values.yaml > /tmp/monitoring.yaml` succeeds; `grep -c 'mimir.rules.kubernetes' /tmp/monitoring.yaml` is at least 1; `grep -E '^kind:' /tmp/monitoring.yaml | sort | uniq -c` shows the Alloy collectors, a kube-state-metrics Deployment and a node-exporter DaemonSet; `grep -n 'glc_' /tmp/monitoring.yaml` finds nothing (no token in Git); `helm template crds prometheus-community/prometheus-operator-crds --version <pinned> | grep -c '^kind: CustomResourceDefinition'` is at least 10.
**Record:** Draft `docs/domains/platform/reference-monitoring.md`: what runs in the cluster and what in Grafana Cloud, versions, features on and off and why, the endpoints (URLs, not credentials), the resource table (finished in step 9).

### 3. The Grafana Cloud credentials in SOPS
**Why:** The Alloy token can write metrics, logs and alert rules into your stack. It goes into a SOPS file that you fill in; the agent writes everything around it ([ADR-0020](../../docs/decisions/0020-secrets-in-git-with-sops-age-ksops.md)). The instance IDs aren't really secret, but they go into the same Secret so the chart reads all credentials from one place.
**Actions:**
- `platform/monitoring/`: `namespace.yaml` (`monitoring`); `secret.enc.yaml`, a Secret `grafana-cloud` with `metrics-username: REPLACE_ME`, `logs-username: REPLACE_ME`, `token: REPLACE_ME`, encrypted in place with `sops encrypt -i` (the placeholders aren't secrets, so the agent may write them); `secret-generator.yaml` (KSOPS, as in `platform/sops-canary`); `kustomization.yaml` with the namespace and the generator.
- 🧑 In **your own terminal**: `git checkout main && git pull`, then the agent's branch (`git checkout <branch>`), then `EDITOR=nano sops edit platform/monitoring/secret.enc.yaml`. Replace the three `REPLACE_ME` values with the two instance IDs and the `glc_...` token from the password manager (right-click pastes in the Windows terminal), save (Ctrl+O, Enter), exit (Ctrl+X). Tell the agent "done"; it commits the file.

**Verify:** `scripts/check-secrets.sh` passes; `grep -c 'ENC\[' platform/monitoring/secret.enc.yaml` is `3`, and `git diff --stat` shows the file changed after your edit (the agent can't see whether the values are real: an encrypted `REPLACE_ME` looks like any other value; step 4 checks the sizes).
**Record:** `reference-monitoring.md`: what's in `grafana-cloud`, what the token may do (its scopes), how to rotate it (new token in grafana.com, `sops edit`, PR, then delete the old token).

### 4. Deliver monitoring through Argo CD
**Why:** From playbook 04 on, nothing reaches the cluster except through a merged PR. Two apps: the CRDs first (no pods; Argo CD needs the types before anything uses them), then `monitoring` with three sources: the chart, its values from this repo, and the `platform/monitoring` folder (namespace, decrypted Secret, later the rules).
**Actions:**
- `bootstrap/project.yaml`: add `https://grafana.github.io/helm-charts` and `https://prometheus-community.github.io/helm-charts` to `sourceRepos`. `bootstrap/` is applied by `install.sh`, not by Argo CD, so the agent reruns `bootstrap/install.sh` after this merge.
- `apps/prometheus-operator-crds.yaml`: the chart at `<PROM_OPERATOR_CRDS_CHART_VERSION>`, destination namespace `monitoring`, automated with `selfHeal: true` and **`prune: false`** (deleting a CRD deletes every object of that type), `syncOptions: [ServerSideApply=true, CreateNamespace=true]` (the CRDs are too big for client-side apply), and the annotation `argocd.argoproj.io/sync-wave: "-1"` so it syncs before the others.
- `apps/monitoring.yaml`: Application `monitoring`, project `platform`, destination namespace `monitoring`. Sources: the chart `k8s-monitoring` from `https://grafana.github.io/helm-charts` at `targetRevision: <K8S_MONITORING_CHART_VERSION>` with `helm.releaseName: monitoring` and `helm.valueFiles: [$values/platform/monitoring/chart-values.yaml]`; this repo at `main` with `ref: values`; this repo at `main` with `path: platform/monitoring`. Automated sync, `prune: true`, `selfHeal: true`; `syncOptions: [ServerSideApply=true]`.
- `scripts/check-versions.sh`: also check both new pins against the `targetRevision`s in `apps/prometheus-operator-crds.yaml` and `apps/monitoring.yaml`.
- `.github/workflows/ci.yml`: render the `k8s-monitoring` chart like Argo CD (`helm template` with the pinned version and `chart-values.yaml`) and pipe it into `kubeconform` with the same flags as Argo CD's render.
- PR, `ci` green, 🧑 squash-merge. Then `git checkout main && git pull` and `bootstrap/install.sh` (applies the project change; Helm reports no change to Argo CD). Refresh `root`.

The first sync takes a few minutes: the Alloy operator starts, then creates the collectors from their custom resources. Pods in `ContainerCreating` for a while are normal; read `kubectl -n monitoring get events --sort-by=.lastTimestamp | tail -20` before calling anything stuck.

**Verify:** `kubectl -n argocd get applications` shows `prometheus-operator-crds` and `monitoring` `Synced` and `Healthy`; `kubectl get crd prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com` finds both; `kubectl -n monitoring get pods -o wide` shows everything `Running` (node-exporter and `alloy-logs` once per node); `kubectl -n monitoring describe secret grafana-cloud` shows three keys, none of exactly 10 bytes (a leftover `REPLACE_ME`); `kubectl -n monitoring logs statefulset/monitoring-alloy-metrics --tail=50` (the real name: `kubectl -n monitoring get statefulsets`) shows no `401`, `403` or `err-mimir-max-series-per-user`; Alloy's own view: `kubectl -n monitoring port-forward statefulset/<alloy-metrics> 12345 >/dev/null &`, then `curl -s localhost:12345/api/v0/web/components | jq -r '.[] | select(.health.state != "healthy") | .localID'` prints nothing (every component healthy); stop it with `kill %1`. 🧑 In Grafana Cloud: **Explore** with the Prometheus data source, `count(up{cluster="homelab"})` is above 5; **Kubernetes Monitoring** (Observability → Kubernetes) shows the `homelab` cluster with both nodes; Explore with Loki, `{cluster="homelab", namespace="argocd"}` shows Argo CD's logs. `kubectl top pods -n monitoring` adds up to under 0.6 GiB.
**Record:** Journal: memory per pod and per node after; what you saw in Grafana Cloud.

### 5. Series budget, Telegram, and the alert path end to end 🧑
**Why:** The free tier stops accepting new series at its limit, so check the count before adding more scrapes. And an alert path nobody has tested is decoration: this step sets up Telegram in Grafana Cloud and proves that a rule written in Git ends as a message on your phone.
**Actions:**
- 🧑 **Series:** in Explore, pick the `grafanacloud-<stack>-usage` data source and query `grafanacloud_instance_active_series` (or open **Administration → Usage insights / Billing**). Tell the agent the number. Budget: below 5,000 now, so the gateway, Argo CD and later playbooks fit under 10,000 with room for spikes (a pod restart briefly doubles its series). If it's above, the agent reads the chart's `metricsTuning` options and drops the largest metric families (`topk(10, count by (__name__) ({cluster="homelab"}))` in Explore, from you) before going on.
- 🧑 **Telegram:** in your stack's Grafana (`https://<stack>.grafana.net`), **Alerting → Contact points**. Grafana Cloud has two Alertmanagers: the Grafana one (for rules made in the UI) and the one behind the ruler that receives the rules Alloy syncs from Git (in the **Choose Alertmanager** drop-down at the top, the one that isn't "Grafana"). In **that** one, add a contact point `telegram` (type Telegram, the bot token and chat ID from *Before you start*), then **Notification policies**: default policy → `telegram`, group by `alertname` and `namespace`, repeat interval 12h; and a nested policy for `severity="info"` with no contact point (muted). Do the same in the Grafana Alertmanager so UI-made alerts land in the same place. Tell the agent "done".
- Agent: a test rule through Git. `platform/monitoring/rules.yaml` with one `PrometheusRule` `lab` (label it so the chart's rule sync picks it up; check the selector in the rendered `mimir.rules.kubernetes` config) and a group `playbook-test` with one alert: `PlaybookTest`, `expr: vector(1)`, `for: 0m`, `labels: {severity: warning}`, `annotations: {summary: "Test alert from playbook 05, synced from Git"}`. Add it to `kustomization.yaml`. PR, `ci` green, 🧑 squash-merge.
- 🧑 Within a few minutes, **Alerting → Alert rules** shows the `lab` group under the data source (not under Grafana), `PlaybookTest` firing, and the Telegram message arrives. Say "done". Agent: remove the test group in a second PR (keep `rules.yaml` for step 6); 🧑 merge; the rule disappears from Grafana Cloud and Telegram gets a "resolved".

**Verify:** The series count is recorded and under budget; the Telegram message arrived and resolved; the rule appeared and disappeared in Grafana Cloud only through Git.
**Record:** `reference-monitoring.md`: the series budget and how to check it, the contact point and policies (written down, since they're set in the UI), how to send a test alert. Journal: series count, how long Git → Telegram took.

### 6. Rules for this lab: the lab going silent, Argo CD, swap, disks
**Why:** The most important alert for a lab watched from outside is the one a self-hosted stack can't send: **the lab stopped talking**. Grafana Cloud's ruler evaluates it while the cluster is dead. Then three things particular to this lab: an Argo CD app that stays out of sync or unhealthy (Git no longer describes the cluster), sustained swapping (zram hides memory pressure until it doesn't, [ADR-0016](../../docs/decisions/0016-zram-swap-on-k3s-nodes.md)), and a node's disk filling up (local-path volumes, etcd and images share the 60 GB).
**Actions:**
- Argo CD metrics: in `bootstrap/argocd/values.yaml`, `metrics.enabled: true` and `metrics.serviceMonitor.enabled: true` for `controller`, `repoServer` and `server` (the CRDs from step 4 make `ServiceMonitor` a valid type now).
- In `rules.yaml`, group `lab`:
  - `LabSilent`: `absent_over_time(up{cluster="homelab"}[10m])` for 5m, critical: "no metrics from the homelab for 15 minutes: both nodes, the network or Alloy are down". This is the dead man's switch; it fires from the cloud.
  - `ArgoCDAppOutOfSync`: `argocd_app_info{sync_status!="Synced"} == 1` for 30m, warning.
  - `ArgoCDAppUnhealthy`: `argocd_app_info{health_status!~"Healthy|Progressing"} == 1` for 15m, warning.
  - `NodeSwapping`: `rate(node_vmstat_pswpin[10m]) > 100` for 30m (pages per second swapped in), warning: "steady swapping means this node needs less load or more RAM". `node_vmstat_pswpin` may not be on the chart's node-exporter allow list; add it to the allow list if it's missing (one series per node).
  - `NodeDiskFilling`: `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.15` for 15m, warning (check these metrics are on the allow list too).
- 🧑 Grafana Cloud's Kubernetes Monitoring app can also install its own recommended alert rules (in the app's **Configuration**). Default **yes**: they cover pods crash-looping, nodes not ready and the like, and they route through the same Alertmanager. Install them, and tell the agent which groups appeared.
- PR, `ci` green, 🧑 squash-merge, `git checkout main && git pull`.

**Verify:** `argocd` stays `Synced`/`Healthy` after its values change (only metrics Services and `ServiceMonitor`s are new); 🧑 in Explore, `up{cluster="homelab", namespace="argocd"}` has three series, all `1`, and `argocd_app_info` lists every application; the `lab` group shows five rules in Grafana Cloud, all `Normal` (`LabSilent` included: it only fires when data stops).
**Record:** `reference-monitoring.md`: the lab rules and why each exists, and which of Grafana's recommended rules are installed.

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
- 🧑 In **your own terminal**, on the agent's branch: open the laptop gateway's keys in Notepad from PowerShell (`notepad "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\gateway\.env"`, close without saving afterwards), then `EDITOR=nano sops edit platform/llm-gateway/secret.enc.yaml` and replace the four `REPLACE_ME` values: `OPENROUTER_API_KEY` and `LITELLM_MASTER_KEY` from that `.env`, the two Langfuse keys from the password manager. Save, exit, tell the agent "done".
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
- **Node down:** `kubectl drain k3s-02 --ignore-daemonsets --delete-emptydir-data`, 🧑 shut `k3s-02` down from Proxmox (**Shutdown**, not reboot), wait 15 minutes. Watch Telegram (a node-not-ready alert from Grafana's recommended rules after its `for:` time; note which alert and how long), and in Grafana Cloud's Kubernetes view see the node go. Note which pods can't move: a pod with a `local-path` volume stays `Pending` until its node is back, because the volume lives on that node. If `alloy-metrics` was on `k3s-02`, there's a gap in the metrics until it reschedules: the collector's single replica is the weak spot, and the reason `LabSilent` waits 15 minutes. 🧑 Start `k3s-02` again, `kubectl uncordon k3s-02`.
- **Lab silent:** the real test is the next time the whole lab is off (planned Proxmox maintenance, a power cut): `LabSilent` should page you after about 15 minutes, and resolve when the lab is back. Don't fake it here (stopping Alloy fights Argo CD's self-heal); write it into the runbook as "first real occurrence = the test", and record it in the journal when it happens.

**Verify:** Each drill that ran ends with every application `Synced`/`Healthy` and, 🧑 in Grafana Cloud, no lab alert firing.
**Record:** Journal: times for each drill, which alert fired and after how long, which pods were stuck while `k3s-02` was down. Draft `docs/domains/platform/runbook-alerts.md`: what each lab alert means and the first three things to check, `LabSilent` first (is the lab powered, is the network up, are the Alloy pods running, is the token expired or revoked: Alloy logs say `401`).

### 11. Prepare the switch to the cluster gateway
**Why:** The switch itself happens after the session, because OpenCode is using the laptop gateway right now. This step writes down everything you'll need, including the way back for when the cluster is down and an agent is needed to fix it.
**Actions:**
- In the `workstation` repo (clone it to `/tmp`, branch, PR, as in playbook 04 step 10): `gateway/README.md` (or a section in the repo README) says the Compose gateway is now the **fallback** and how to use it: `docker compose ... up -d` from PowerShell, then point `LLM_GATEWAY_URL` back at `http://host.docker.internal:4000` and recreate the container. Keep `gateway/config.yaml` and the cluster's `platform/llm-gateway/config.yaml` in step: same aliases; add a line to both saying the other exists.
- Write `docs/domains/ai-stack/runbook-gateway-fallback.md`: when (cluster or `k3s-*` down, `llm.<ip>.nip.io` doesn't answer, nip.io down), the steps there and back, and how to check which one a container is using (`echo $LLM_GATEWAY_URL`).

**Verify:** The `workstation` PR's checks pass (🧑 merge); the runbook is in the handbook branch.
**Record:** Journal.

### 12. Finish
**Actions:** Close the journal entry (what broke, memory per pod and per node before and after, the series count, drill times, how long a merge takes to reach the cluster and Git takes to reach Telegram). Fill in `docs/domains/platform/index.md` (monitoring added to the diagram, links to `reference-monitoring` and `runbook-alerts`) and `docs/domains/ai-stack/index.md` (the gateway runs on k3s now). ADR-0021 and ADR-0022: ask whether they still hold and set them `accepted`. Open questions: close "Observability stack" with ADR-0021. Update the playbook catalog (05 done, with the date) and the decision log. Remind the human to export the session and check it with `grep -cE 'sk-or-v1-[0-9a-f]{20}|sk-lf-[0-9a-f-]{20}|homelab-infra=[0-9a-f]{8}-|K3S_TOKEN=[0-9a-f]{16}|client-key-data: [A-Za-z0-9]|BEGIN OPENSSH PRIVATE KEY-----.{0,4}b3Bl|AGE-SECRET-KEY-1[0-9A-Z]{20}|glc_[A-Za-z0-9+/=]{20}|[0-9]{8,10}:AA[0-9A-Za-z_-]{30}'` before sharing (the last two are the Grafana Cloud token and a Telegram bot token). Open the handbook PR.

**After the session 🧑** (in this order):
1. Exit OpenCode. In **PowerShell**, point new containers at the cluster gateway: `setx LLM_GATEWAY_URL "http://llm.<k3s-01-ip>.nip.io"`. Close PowerShell and open a new window (`setx` only affects new windows).
2. Stop the laptop gateway: `docker stop llm-gateway`. (It's the fallback now; `docker start llm-gateway` brings it back.)
3. Recreate the container so it picks up the new URL: `devpod up "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops" --recreate --ide none`, open a shell in it (the `docker ps` and `docker exec` lines from *Before you start*), `gh auth login` again.
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
- Grafana Cloud: the `homelab` stack receiving metrics, logs and events; Telegram contact point and policies; the gateway dashboard; all written down in `reference-monitoring.md`.
- Docs updated: `docs/domains/platform/` (index, reference-monitoring, runbook-alerts, reference-argocd), `docs/domains/ai-stack/` (index, reference-gateway, runbook-gateway-fallback), ADRs 0021 and 0022, open questions, playbook catalog, decision log, journal.
- Next playbook: 06, Hermes on k3s: the gateway's second client, which brings virtual keys per client (and the small database they need).

## Video
Not recorded yet. Good candidates: step 5 ("an alert rule in a pull request, a message on my phone") and the first real `LabSilent` ("my homelab died and the cloud told me").
