---
type: adr
title: Build the SRE crews with CrewAI, give them abilities only through MCP servers, and expose each crew to Hermes as an MCP tool
description: The lab's SRE automation is a small set of CrewAI crews in homelab-agents, packaged as one MCP server that Hermes calls; the crews' abilities come from MCP servers, so the orchestration framework can be replaced without rewriting tools.
domain: ai-stack
tags: [crewai, langgraph, mcp, agents, sre, hermes]
status: proposed
created: 2026-11-04
updated: 2026-11-09
visibility: public
reuse: portable
related: [0008-vendor-neutral-ai-stack.md, 0023-hermes-on-k3s-pod-as-sandbox.md, 0025-gateway-virtual-keys-with-postgres.md, 0028-agent-read-access-through-upstream-mcp-sidecars.md, 0029-agent-writes-only-through-an-approval-gated-mcp-server.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0027. Build the SRE crews with CrewAI, give them abilities only through MCP servers, and expose each crew to Hermes as an MCP tool

## Context
The lab's goal includes reusable agents that help run Kubernetes. Hermes (ADR-0023) is the chat front door and gives every new alert a quick read-only look. Some work needs more than one pass: an investigation that plans checks, gathers evidence from the cluster and from metrics and logs, and writes it up; or a weekly capacity review. The open question was the framework: CrewAI or LangGraph, with the leaning "CrewAI, tools as MCP servers so it stays swappable" (ADR-0008 names MCP as the tool standard).

Checked on 2026-11-04: CrewAI 1.15.35 (Python 3.10 to 3.13) connects to MCP servers natively (stdio, SSE, streamable HTTP, with static tool filters), uses its own OpenAI client for an OpenAI-compatible endpoint, so the LiteLLM gateway's aliases work without the `litellm` extra, and needs `mcp<2`. Its base install is large (it brings Chroma and LanceDB), and it sends anonymous telemetry unless told not to. Hermes is an MCP client with per-server trust levels.

Repo placement was decided with Shawn on 2026-10-30: SRE agents are not product work, so they live in `homelab-agents` (with Hermes' skills), deployed by `homelab-gitops`, not in `ai-factory`.

## Options considered
1. **CrewAI crews as an MCP server Hermes calls**: role-based agents map onto SRE roles; the crews are tools for Hermes, so there's one chat agent and one approval surface.
2. **LangGraph graphs**: explicit state machines, checkpoints and human-in-the-loop interrupts; more code per workflow, and its strengths (long, resumable flows) aren't needed by a two-minute investigation.
3. **Only Hermes, with more skills**: cheapest, one process; but a skill is one agent following instructions, with no separation between planning, gathering and writing, and no way to compare the two approaches.
4. **Crews with their own chat or alert intake**: a second front door, a second set of Slack tokens, and duplicate approval logic.

## Decision
Option 1:
- `homelab-agents/crews` holds the crews (`investigate_alert`, `weekly_capacity_report`) and a `find_runbook` helper, packaged as one MCP server (streamable HTTP, bearer token, read-only annotations), built into an image by CI and deployed in namespace `sre` by Argo CD.
- Crews get **no abilities of their own** beyond reading the handbook's runbooks: cluster and Grafana access come from MCP servers (ADR-0028). Moving to LangGraph or another framework rewrites the orchestration only.
- Models through the gateway with their own virtual key `crews` (`fast` and `code`, monthly budget, rate limit; ADR-0025). CrewAI memory, knowledge, telemetry and tracing are off.
- Bounded runs: few iterations per agent, a time limit per crew, one run at a time.
- Hermes decides when to call a crew (`alert-triage` for warning and critical alerts; a weekly cron for capacity) and falls back to its own checks when the crews aren't available.

## Consequences
- Two layers of agents cost more per alert than Hermes alone (roughly 10 to 20 model calls per investigation). The playbook measures quality, time and cost side by side; if the crew isn't clearly better, `alert-triage` stops calling it and the crews keep the reports.
- CrewAI's release pace means frequent pins; the image is rebuilt and the digest bumped by PR.
- Hermes becomes the one place where a person meets the agents, and the one place approvals happen (ADR-0029).
- The crews pod is the second-largest agent workload after Hermes (about 450 Mi of requests with `lab-actions`). Both prefer `k3s-03` (ADR-0031), where Backstage also plans to run; the capacity report keeps that budget visible.

## In a team or enterprise setting
Teams usually end up with one conversational agent per audience and many narrow workers behind it. Keeping the workers behind a tool protocol (MCP) with read-only defaults lets the platform team swap frameworks, models and vendors per worker, and keeps approvals and audit in one front door.
