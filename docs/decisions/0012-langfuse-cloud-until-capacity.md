---
type: adr
title: Use Langfuse Cloud (EU, free tier) until the lab can host Langfuse
description: Neither the 8 GB laptop nor the 8 GB Proxmox host can spare the ~4 GB self-hosted Langfuse needs, so traces go to Langfuse Cloud's free Hobby tier over OpenTelemetry until there is capacity.
domain: ai-stack
tags: [langfuse, observability, opentelemetry, capacity]
status: accepted
created: 2026-10-23
updated: 2026-10-23
visibility: public
reuse: portable
related: [0010-langfuse-for-tracing-and-evals.md, 0008-vendor-neutral-ai-stack.md, ../domains/proxmox/reference-hardware.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0012. Use Langfuse Cloud (EU, free tier) until the lab can host Langfuse

## Context
ADR-0010 chose self-hosted Langfuse, local first and k3s later. The hardware inventory (2026-10-23) shows 8 GB of RAM on the laptop and 8 GB on the Proxmox host, about 5.8 GB free. Self-hosted Langfuse runs six containers (web, worker, Postgres, ClickHouse, Redis, MinIO) and needs roughly 4 GB even for light use, which neither machine can spare next to k3s.

## Options considered
1. **Langfuse Cloud, Hobby tier (free):** 50k units a month, 30 days of data, 2 users, US/EU/JP regions. Prompts and outputs are stored by Langfuse.
2. **No tracing until there is more hardware:** spend visible only in OpenRouter Activity.
3. **Self-host anyway:** start it only for short sessions; the machines would swap.

## Decision
Option 1, EU region, chosen by Shawn on 2026-10-23. ADR-0010 still stands as the target: the gateway sends traces over OpenTelemetry (LiteLLM `langfuse_otel`), so moving to self-hosted Langfuse is a URL and key change when hardware allows (for example a 32 GB mini PC as a second node).

## Consequences
- Traces and costs are visible from the first gateway hookup, at no cost and no load on the lab.
- Prompts leave the lab. Nothing sensitive goes into prompts; if that changes, the gateway is switched to metadata-only logging.
- Export anything worth keeping (eval datasets, cost trends for posts) within 30 days.
- Usage is checked occasionally against the 50k-unit limit once scheduled agents run.

## In a team or enterprise setting
Start on the SaaS tier to prove value, keep the integration on an open protocol, and self-host when data residency or volume demands it. The decision record makes the exit path explicit before the data piles up.
