---
type: adr
title: Give each gateway client its own LiteLLM virtual key, stored in a small in-cluster Postgres that is rebuilt rather than backed up
description: The LLM gateway gets a single-replica Postgres in its namespace for virtual keys and spend logs; Hermes is the first client with its own key (cheap aliases only, monthly budget, rate limit), while OpenCode keeps the master key until the gateway has TLS.
domain: ai-stack
tags: [litellm, gateway, virtual-keys, postgres, budgets, k3s]
status: accepted
created: 2026-11-01
updated: 2026-11-08
visibility: public
reuse: portable
related: [0008-vendor-neutral-ai-stack.md, 0022-llm-gateway-on-k3s.md, 0023-hermes-on-k3s-pod-as-sandbox.md, ../domains/ai-stack/reference-gateway.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0025. Give each gateway client its own LiteLLM virtual key, stored in a small in-cluster Postgres that is rebuilt rather than backed up

## Context
ADR-0022 moved the LiteLLM gateway to k3s with one master key and no database, and planned per-client keys for when Hermes became the second client. Hermes runs unattended, answers webhooks from the internet, and shares its container with the commands it runs (ADR-0023), so its key must be limited and revocable on its own. LiteLLM's virtual keys (per-key models, budgets, rate limits, aliases in logs and traces) need Postgres.

## Options considered
1. **Plain Postgres StatefulSet** in `llm-gateway`: one pod, about 50 to 100 Mi, a `local-path` volume.
2. **CloudNativePG operator**: backups, failover and upgrades handled, but an operator plus an instance costs more memory than the database's job is worth here.
3. **Free hosted Postgres** (Neon, Supabase): no cluster memory, but the gateway would depend on the internet and a third party for every key check.
4. **No database; a second LiteLLM instance per client** with its own master key: no budgets per key, double the memory.

## Decision
Option 1: `postgres` (pinned Alpine image), 2 Gi `local-path`, small `shared_buffers` and connection limits; LiteLLM connects with split database variables so the password lives once in the gateway's SOPS Secret, next to a salt key that must never change. `allow_requests_on_db_unavailable` stays off.

The first virtual key is `hermes`: aliases `fast` and `code` only, 5 USD per 30 days, 30 requests per minute. The human creates it with the master key in their own shell and puts it into Hermes' SOPS Secret; the agent never sees it. OpenCode keeps the master key for now.

The database is **rebuilt, not backed up**: it holds keys and spend logs only. If it's lost, the keys are recreated with the same aliases and their new values go into SOPS; spend history lives on in Langfuse and Grafana Cloud.

**Mount note (2026-11-08):** postgres 18 sets `PGDATA` to `/var/lib/postgresql/18/docker`, so the StatefulSet volume must mount at `/var/lib/postgresql` — not the pre-18 `/var/lib/postgresql/data`. Mounting the old path leaves the database on the pod's ephemeral storage, and a restart wipes every virtual key (this happened during playbook 06).

## Consequences
- Hermes' spending has a hard cap of its own and a name in Langfuse and the gateway metrics; revoking it touches nothing else.
- The gateway now depends on Postgres: if `postgres-0` is down, every virtual key fails (the master key still works). An alert covers it, and the volume ties it to one node.
- About 100 Mi more memory in `llm-gateway`, plus LiteLLM's own increase with a database.
- Rebuilding means a short manual step per key; with two or three clients that's cheaper than a backup job. Revisit when keys multiply (playbook 07 adds crews) or when spend logs matter for reporting.
- The master key still crosses the LAN in plain HTTP and is used by OpenCode; moving OpenCode to a virtual key waits for TLS on the gateway (open question).

## In a team or enterprise setting
A shared gateway issues a key per team, service and agent, each with a budget and model list, from a managed, backed-up database, and ties keys to identities (SSO, workload identity) rather than to pasted strings. The habit worth keeping from the lab: an autonomous agent never gets the master key, and its budget is enforced by the gateway, not by the agent.
