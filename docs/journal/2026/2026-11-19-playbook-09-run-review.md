---
type: journal
title: Review of the playbook 09 run
description: No secret reached the model, but real email addresses landed in public test fixtures; the run needed 30+ fix PRs and two very long sessions, and most lessons are now folded back into playbook 09 and RUNNING.md.
domain: career
tags: [job-search, review, secrets, privacy, opencode, autonomy]
status: active
created: 2026-11-19
updated: 2026-11-19
visibility: public
reuse: portable
related: [../../../playbooks/09-job-search/PLAYBOOK.md, ../../../playbooks/RUNNING.md, 2026-11-15-09-job-search.md, ../../meta/opencode-permissions.md]
blog: candidate
---

# Review of the playbook 09 run

Two OpenCode sessions, both exported: 96 hours with 121 human messages and 13 context compactions, then 5 hours with 15 messages and 2 compactions. Together 1,649 shell commands, 300 file edits, 39 failed tool calls, all on the `code` alias.

## Secrets: clean

- No real credential reached the model. The export check flagged six `Bearer sk-…` strings; all six were example keys inside LiteLLM documentation pages the agent had fetched (`webfetch` results), and all six were rejected by the gateway (`401`, with a known-good key returning `200` as control). The playbook and RUNNING.md now say to classify a hit by where it sits before reacting.
- The deny rules did their job. Refused: reading `platform/hermes/managed/.env`, a `kubectl exec` into the gateway that would have used `$LITELLM_MASTER_KEY`, `gh auth token` twice (once to read the registry), and, before the new permission policy, `git commit --amend` plus `--force-with-lease`.
- One near miss in conversation, not in a command: the agent asked the human to export the `jobs` key from a decrypted Secret into a shell for drill 2. Declined; the drill ran as a one-off Job with `secretKeyRef`. New RUNNING.md rule: never ask the human to expose a secret for you.

## Privacy: one real finding

Five test fixtures in `homelab-agents` (public) were alert emails whose `To:` line held the real job-alert mailbox address. No names and no tracking or unsubscribe tokens. Being replaced with synthetic fixtures plus a CI grep for personal markers (OpenCode PR in progress at the time of this review); the history was not rewritten, since the address is a receive-only alert mailbox. New RUNNING.md rule: test data is synthetic.

## Bugs the run found (each fixed by PR)

| Area | What broke | Lesson now in the playbook |
|---|---|---|
| CronJob spec | `activeDeadlineSeconds` on the CronJob spec is rejected | it belongs under `jobTemplate.spec` |
| PodSecurity | Job never admitted: git-sync init container lacked `runAsNonRoot` | copy the Deployment's security contexts |
| Entry point | `python -m job_search.triage` exited 0 doing nothing (no `__main__` guard) | subprocess regression test |
| Network | proxy's own ingress policy admitted only `app: job-search` | triage has its own label; widen both sides |
| Feed | `UNSEEN` + read-only mailbox would re-score the same alerts daily | Message-ID dedupe state in the vault |
| Drafting | Checker never saw the CV; slot check ran on the Checker's summary | Writer-only slot check, Checker gets the CV |
| Budget | budget error retried and shown as "unparseable reply" | budget/401/402 are non-retryable with a clear message |
| Skill | Hermes offered inline drafts and "manual reads" after tool errors | skill 0.2.4: report and stop |

## Autonomy: what to change next

- **Polling.** 207 `sleep` commands despite the rule to use `gh pr checks --watch`. Proposal: add `sleep [1-9][0-9]*` as `ask` in `opencode.json`, so long sleeps need a reason and `--watch` / `kubectl rollout status` / `kubectl wait` become the easy path.
- **Session length.** The rule "one session per step group" was not followed: one session ran four days through 13 compactions. Its hand-off at the end (a draft PR whose description held the design and remaining work) worked well and is the pattern to copy.
- **Hermes inspection.** `kubectl exec … hermes skills list` / `cron list` / `mcp list` were denied 9 times under the new blanket `kubectl exec` deny, and each time the human ran them. Proposal: narrow `ask` overrides for exactly those read-only commands, placed after the exec deny.
- **Image digests.** The agent tried `gh auth token` to query the registry. Proposal: a small read-only script in `homelab-gitops` that pipes the digest from `gh api` (allowed), so the "never retype a digest" rule has a sanctioned tool.
- **Stray clone.** The second session wrote the journal from `~/code/github.com/ssaav5-ai-labs/handbook` instead of `/knowledge/handbook`; the work merged, but the clone should be removed and AGENTS.md should name the handbook path.
- **What went well.** Self-verification after merges, digests piped from the registry, PRs merged only on green, and drills run as code or in-cluster Jobs rather than by hand.
