---
type: runbook
title: Respond to a monitoring alert
description: What each lab alert means, the first three things to check, and how alerts reach you.
domain: platform
status: draft
visibility: public
reuse: lab-specific
created: 2026-11-04
updated: 2026-11-04
related: [index.md, ../../decisions/0021-grafana-cloud-for-monitoring.md, ../../../playbooks/05-monitoring-gateway/PLAYBOOK.md]
---

# Respond to a monitoring alert

Alerts are Grafana-managed rules in the `lab` group, synced from Git (`platform/monitoring/rules.yaml`
in `homelab-gitops`) by `mimirtool` in CI, and routed to **Slack**. They evaluate in Grafana Cloud, so
they keep working when the lab is down. We run only this `lab` group; Grafana's stock "recommended"
rules are not installed, so the node alert below is our own `NodeNotReady`.

## LabSilent (critical, ~15 min)

`absent_over_time(up{cluster="homelab"}[10m])` for 5m. Grafana Cloud has heard nothing from the
homelab for ~15 minutes: both nodes, the network, or Alloy is down. This is the dead man's switch.

1. Is the lab powered? Proxmox host and both k3s VMs up?
2. Is the network up (router, switch, WAN)? Can you reach the LAN/VPN?
3. Are the Alloy pods running (`kubectl -n monitoring get pods`)? If they are, check Alloy logs for
   `401`: the Grafana Cloud token is expired or revoked.

**First real occurrence is the test.** Don't fake this one (stopping Alloy fights Argo CD's
self-heal). The next planned outage or power cut is when we verify the page and the ~15-minute
timing; record it in the journal when it happens.

## NodeNotReady (critical, ~5 min)

`kube_node_status_condition{condition="Ready",status="true"} == 0` for 5m. A k3s node stopped
heartbeating. This is our rule, not Grafana's stock node alert.

1. `kubectl get nodes`: which node, and is it `NotReady` or gone?
2. Proxmox: did the VM crash or reboot? Check the host and the VM console.
3. If it was planned, was it drained first? If not, check `journalctl -u k3s` on that node when it is
   back.

## LiteLLMDown (critical, ~5 min)

`up{namespace="llm-gateway"} == 0 or absent(...)` for 5m. Alloy cannot scrape the gateway.

1. `kubectl -n llm-gateway get pods`: is `litellm` Running and Ready?
2. `kubectl -n llm-gateway logs deploy/litellm --tail=50`: startup or config/secret error?
3. Service and ServiceMonitor labels: the Service must carry `app: litellm` for the ServiceMonitor
   selector to match. Is `/metrics/` reachable in-cluster?

Fallback while the cluster gateway is down: the laptop Compose gateway (see
`../ai-stack/reference-gateway.md`).

## PodCrashLooping (warning, ~15 min)

`increase(kube_pod_container_status_restarts_total[15m]) > 3` for 15m, in `argocd`, `monitoring` or
`llm-gateway`.

1. `kubectl -n <ns> get pods`: which pod, how many restarts?
2. `kubectl -n <ns> describe pod <pod>`: last state, exit code, `OOMKilled`?
3. `kubectl -n <ns> logs <pod> --previous`: the crash reason.

## NodeSwapping (warning, ~30 min)

`rate(node_vmstat_pswpin[10m]) > 100` for 30m. Sustained swap-in means the node is short on memory.

1. `kubectl top nodes` and `kubectl top pods -A`: who is using memory?
2. `free -m` on the node: how much swap is in use?
3. Right-size the offender (requests/limits) or move it; see the right-sizing note in the playbook.

## NodeDiskFilling (warning, ~15 min)

Root filesystem
`node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.15`
for 15m.

1. `df -h` on the node: which mount is filling?
2. Largest consumers: container images (`k3s crictl images`), logs (`journalctl --disk-usage`),
   `/var/lib`.
3. `kubectl get events -A`: evicted pods or image-pull pressure?

## ArgoCDAppOutOfSync (warning, ~30 min)

`argocd_app_info{sync_status!="Synced"} == 1` for 30m. Git no longer describes the cluster, or a sync
is failing.

1. `kubectl -n argocd get applications`: which app, and what does `argocd app get <app>` show?
2. Is the sync failing on a secret (SOPS/age) or a repo credential? Check the Application
   conditions.
3. Does the app's path in `homelab-gitops` still exist and render (CI passed)?

## ArgoCDAppUnhealthy (warning, ~15 min)

`argocd_app_info{health_status!~"Healthy|Progressing"} == 1` for 15m.

1. `kubectl -n argocd get applications`: which app is `Degraded`/`Missing`?
2. `kubectl -n <app-ns> get pods` and events: what is failing?
3. Did a recent merge change a resource the cluster cannot satisfy (image, quota, selector)?

## Resolve and record

When the cause is fixed, confirm the alert returns to `Normal` in Grafana Cloud and all apps are
`Synced`/`Healthy`. Record anything that surprised you in the run journal; if a check here was missing
or wrong, fix this runbook in the same PR.
