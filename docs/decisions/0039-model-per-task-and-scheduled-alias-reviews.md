---
type: adr
title: Pick the model per task before a session starts, and review what each gateway alias points to on a schedule
description: Claude names the gateway alias for each playbook step and OpenCode keeps it for the whole session (switching mid-session throws away the prompt cache); a monthly review plus event triggers and a small replay eval decide when the model behind `fast`, `code` or `reason` should change.
domain: ai-stack
tags: [llm-gateway, aliases, model-selection, opencode, playbooks, evals, cost, prompt-cache]
status: proposed
created: 2026-11-19
updated: 2026-11-19
visibility: public
reuse: portable
related: [0007-ai-first-playbooks.md, 0008-vendor-neutral-ai-stack.md, 0012-langfuse-cloud-until-capacity.md, 0038-claude-coordinates-changes-gitops-only-write-path.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0039. Pick the model per task before a session starts, and review what each gateway alias points to on a schedule

## Context
OpenCode only sees gateway aliases (`fast`, `code`, `reason`; ADR-0008), and `opencode.json` sets `gateway/code` as the model for everything. Nothing decides which alias suits a playbook step, so design and security work gets the same model as routine edits, and journaling gets a stronger model than it needs.

Switching models has a cost. Prompt caches are kept per model. In the AI cost estimate (22 Oct to 12 Nov 2026), 94% of input tokens were cache hits. Changing the model in the middle of a session sends the whole context again at the full price, and the new model starts without the conversation's cached state.

The models behind the aliases were chosen once (2026-10-22) and nothing checks them since. The market moves monthly: new models, price cuts, and providers that support caching or don't. The same model's price on OpenRouter varied about 3x between providers in the cost report.

## Options considered
1. **Keep `code` for everything**: simple, best cache use; overpays for journaling, underpowers design and security steps.
2. **Let OpenCode or the human switch models mid-session when a step feels hard**: flexible; loses the cache at every switch, and choices go unrecorded.
3. **Choose the alias per step before the session starts, change it only at session boundaries, and review alias targets on a schedule with our own eval**: one more field in playbooks and a recurring task; keeps the cache and makes model choice deliberate and measurable.

## Decision
We will use option 3.

**Model per task**
- Each playbook step names an alias in a `**Model:**` line. Defaults: `reason` for design, architecture, security, RBAC and secret-handling steps and for run reviews; `code` for building, editing and verifying; `fast` for journaling, summaries and classification.
- Claude's kickoff prompt names the alias for the first step group. The agent starts the session on it (`opencode --model gateway/<alias>`, or by choosing it with `/models` before the first message).
- The model doesn't change inside a session. Change it only at the session boundaries RUNNING.md already requires (a fresh session every two or three steps).
- `opencode.json` pins a model per agent: `plan` uses `reason`, `build` uses `code`, and a `scribe` subagent uses `fast` for journal and summary writing. Subagents run in their own context, so using them doesn't cost the main session its cache.
- **Escalation**: if a step fails its Verify twice, the agent stops and reports. Claude restarts that step in a new session on `reason`, handing over through the journal.
- The journal records the alias used for each step group.

**Alias review**
- **Monthly**: Claude compares each alias's current model with candidates on OpenRouter. It looks at price per Mtok (input, output and cached input), whether providers support caching, context length, tool-calling reliability, public coding and agent benchmarks (for example SWE-bench and Terminal-Bench), and our own cost and retry numbers per step from Langfuse. The output is a short keep-or-trial report. Nothing changes automatically.
- **On events**: a major model release, a price change on a current model, repeated gateway errors (for example the `code` 402), or a step that keeps failing starts a review early.
- **Our eval decides**: a small replay set of real past playbook steps (from scrubbed exports) runs against a candidate model behind a trial alias such as `code-next`. A candidate is promoted only if it wins on success rate and retries at an acceptable cost.
- **Recording**: promoting a candidate is a homelab-gitops PR that changes the alias target. That PR also updates the alias table in the gateway reference and adds a journal entry with the reason. A new ADR is needed only if an alias changes its role. Each alias gets OpenRouter provider preferences, so its price and cache behaviour don't drift between providers.
- A playbook may pick a different existing alias for one step. It doesn't define aliases of its own.

## Consequences
- The prompt cache stays warm within a session, and stronger models are used only where they pay off.
- Playbooks gain a `Model:` line per step, so the template and RUNNING.md change.
- A recurring review task and a replay set need building and keeping current. The replay set is the main new work, and the first review can run without it on price and benchmarks alone.
- The alias table in the gateway reference becomes a live record that must match homelab-gitops.
- Revisit after three monthly reviews: if none changed anything, review quarterly instead.

## In a team or enterprise setting
A platform team owns the model catalogue behind stable aliases, like a base-image catalogue: consumers pick an alias by job (fast, code, reason), and the platform team swaps models under them after an eval on the company's own tasks, not leaderboards. Routing rules per task live in the playbooks and runbooks that teams already follow, and cost per task is reported from tracing.
