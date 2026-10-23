---
type: adr
title: Use self-hosted Langfuse for AI tracing and evaluation
description: Langfuse, self-hosted on k3s and fed by OpenTelemetry, is the tracing, cost and evaluation tool for agents and the AI dev factory.
domain: ai-stack
tags: [langfuse, langsmith, observability, evals, opentelemetry]
status: accepted
created: 2026-10-20
updated: 2026-10-20
visibility: public
reuse: portable
related: [../domains/ai-stack/index.md, 0008-vendor-neutral-ai-stack.md, 0012-langfuse-cloud-until-capacity.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0010. Use self-hosted Langfuse for AI tracing and evaluation

## Context
The AI dev factory, SRE agents and local automations need tracing, cost tracking, prompt management and evaluations. Constraints from ADR-0008: lowest cost, no vendor lock-in.

## Options considered
1. **Langfuse**: MIT-licensed core (some enterprise modules licensed separately), self-hosts on Kubernetes, accepts OpenTelemetry. Acquired by ClickHouse in January 2026; licensing stated unchanged.
2. **LangSmith**: polished hosted platform with a free tier; proprietary, self-hosting requires an Enterprise contract.
3. **Decide later.**

## Decision
Langfuse, chosen by Shawn on 2026-10-20. It runs locally next to the LLM gateway at first, then moves to k3s in playbook 06. Agents, harnesses and the gateway send traces over OpenTelemetry, never through a Langfuse-only SDK where an OTel path exists.

> **2026-10-23:** hardware limits mean Langfuse Cloud is used until the lab has capacity; see [ADR-0012](0012-langfuse-cloud-until-capacity.md). This decision remains the target.

## Consequences
Another stateful service to run (Postgres, ClickHouse, object storage), which is also real SRE practice. Because traces use OpenTelemetry, LangSmith or another backend can be added later with configuration only.

## In a team or enterprise setting
Self-hosted LLM observability keeps prompts and traces inside the company's boundary, a common requirement for regulated or security-conscious organizations.
