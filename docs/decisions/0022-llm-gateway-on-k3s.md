---
type: adr
title: Run the LiteLLM gateway on k3s as plain manifests, reachable over HTTP on the LAN, with the laptop Compose file as the fallback
description: The LLM gateway moves from the laptop to the cluster as an Argo CD app with its config in Git and its keys in SOPS, keeps the same master key and aliases, sends traces to Langfuse Cloud and metrics to Grafana Cloud, and keeps the laptop Compose file for when the cluster is down.
domain: ai-stack
tags: [litellm, gateway, k3s, argocd, sops, langfuse, opentelemetry]
status: proposed
created: 2026-10-30
updated: 2026-10-30
visibility: public
reuse: portable
related: [0008-vendor-neutral-ai-stack.md, 0012-langfuse-cloud-until-capacity.md, 0020-secrets-in-git-with-sops-age-ksops.md, 0021-grafana-cloud-for-monitoring.md, ../domains/ai-stack/reference-gateway.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0022. Run the LiteLLM gateway on k3s as plain manifests, reachable over HTTP on the LAN, with the laptop Compose file as the fallback

## Context
ADR-0008 put a LiteLLM gateway in front of OpenRouter so every tool calls aliases, not vendor models. It has run in Docker on the 8 GB laptop since playbook 00, where it takes about 400 MB and stops when the laptop sleeps. The next playbooks run agents on the cluster (Hermes, the SRE crews, the AI factory), and they need the gateway there. Langfuse Cloud tracing (ADR-0012) was decided but never switched on. The cluster has no lab DNS or certificate authority yet.

## Options considered
1. **LiteLLM's Helm chart:** built around a Postgres database (virtual keys, spend logs) and, by default, a bundled database chart. More memory and moving parts than one client needs.
2. **Plain manifests with kustomize:** a Deployment, Service, Ingress, the config as a ConfigMap generated from `config.yaml`, keys in a SOPS Secret. No database: one master key, the global budget in the config, the OpenRouter key's own monthly limit as the hard stop.
3. **Keep it on the laptop:** no work now; cluster agents would call across to a laptop that isn't always on.

For the laptop's access: **HTTPS with Traefik's self-signed certificate** (every client rejects it without extra trust setup), **a lab CA with cert-manager** (the right end state, but it belongs with lab DNS), or **plain HTTP on the home LAN** with the bearer key.

## Decision
Option 2, with plain HTTP through Traefik at `llm.<k3s-01-ip>.nip.io` for the laptop and `http://litellm.llm-gateway.svc:4000` inside the cluster. The cluster gateway reuses the laptop's master key and aliases, so switching a container is one URL change. Traces go to Langfuse Cloud EU over OpenTelemetry (`langfuse_otel`), metrics to Grafana Cloud (`prometheus` callback, scraped by Alloy with only the dashboard's metric families kept). The laptop Compose file stays in the `workstation` repo as the documented fallback for when the cluster, or nip.io, is down.

## Consequences
- The laptop gets about 400 MB back; cluster agents get a gateway that's always on.
- An agent can't use the cluster gateway to fix a cluster that's down: the fallback runbook switches back to the laptop gateway first.
- The master key crosses the home LAN in plain HTTP. Acceptable on a private network for now; it becomes HTTPS with the lab CA, and per-client virtual keys (with a small database) come with Hermes in playbook 06.
- The OpenRouter key's monthly limit stays the hard spending cap; LiteLLM's global budget is only in memory and resets when the pod restarts.
- Prompts and outputs go to Langfuse Cloud, as ADR-0012 accepted.
- The config exists twice (cluster and laptop fallback) and must be kept in step; both files say so.

## In a team or enterprise setting
A shared gateway is a platform service: replicated, behind TLS from the company CA, with SSO or per-team virtual keys, budgets per key, a database for spend logs, and traces into the company's observability stack. Keeping a documented fallback path for the platform team itself (a break-glass key straight to a provider) is the same idea as the laptop gateway here.
