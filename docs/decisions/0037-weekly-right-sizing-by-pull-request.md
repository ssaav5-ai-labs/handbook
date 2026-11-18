---
type: adr
title: Right-size the lab every week with a pull request that an agent opens and a human merges
description: A weekly CronJob turns the crews' deterministic capacity proposals into one pull request in homelab-gitops, through a GitHub App scoped to that repo; the human merges from Slack through an approval-gated lab-actions tool (or in GitHub), Argo CD applies, and the next week's run proposes a revert if the change hurt.
domain: ai-stack
tags: [right-sizing, gitops, github-app, cronjob, agents, capacity, argocd]
status: proposed
created: 2026-11-13
updated: 2026-11-13
visibility: public
reuse: portable
related: [0019-gitops-with-argo-cd-app-of-apps.md, 0027-crewai-crews-as-mcp-tools.md, 0028-agent-read-access-through-upstream-mcp-sidecars.md, 0029-agent-writes-only-through-an-approval-gated-mcp-server.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0037. Right-size the lab every week with a pull request that an agent opens and a human merges

## Context
Right-sizing has been done by hand at the end of every playbook (05 step 9, 06 step 8, 07 step 10), each time after a week of waiting for data, which leaves a thread or a reminder open just for that check. Since playbook 07 the crews compute the proposals deterministically every Monday (`weekly_capacity_report`: pods and 7-day peaks fetched in code, the playbook 05 rule applied in Python, totals summed in code), and the numbers have been spot-checked against `kubectl` and Grafana Explore. What's missing is the step from "a table in Slack" to "a change in Git".

Constraints: the cluster changes only through Git and Argo CD (ADR-0019); agents don't write to the cluster except through `lab-actions` with a human "Allow once" (ADR-0029); Hermes' cron sessions deny write tools by design; the lab runs on a free GitHub org.

## Options considered
1. **Keep it manual**: read the Monday report, ask OpenCode for a PR. Works, but someone has to remember, and it's the thing the lab repeats most.
2. **A Hermes cron job that edits Git**: Hermes would need a GitHub credential and an approved write tool; cron sessions deny untrusted writes, so it can't run unattended, and giving Hermes a Git credential widens its blast radius for every chat.
3. **A `lab-actions` tool that applies the new resources directly**: fast, but a direct write to managed objects; Argo CD's self-heal would revert it, and it bypasses review.
4. **A weekly Kubernetes CronJob that opens a pull request**: the same deterministic code computes the proposal; a GitHub App installed on `homelab-gitops` only opens one PR; CI checks it; the human merges; Argo CD applies it. The job holds the GitHub credential and nothing else; the numbers come from the crews over MCP.

## Decision
We will run option 4. Every Monday before Hermes' capacity report, a CronJob `rightsize` in namespace `sre`:
- calls a read-only tool `capacity_proposals` on the crews' MCP server (structured JSON from the same code as `weekly_capacity_report`);
- keeps only workloads listed in `platform/rightsize-targets.yaml` (an allow-list mapping each workload to the file and YAML path of its resources), and only changes of at least 15 % and 32 Mi;
- edits those files, pushes one branch `rightsize/<date>` and opens (or updates) one PR labelled `rightsize` with the evidence table, the rule and the rollback note;
- checks the last merged `rightsize` PR: if a changed workload was `OOMKilled` or restarted since the merge, it opens a revert PR instead of new changes.

The GitHub App has `contents: write` and `pull_requests: write` on `homelab-gitops` only. The `main` ruleset has no bypass list, so neither the App nor anyone else lands a change without a PR and green checks. The job's code never merges. Hermes' Monday report links the open PR.

Merging is a second `lab-actions` tool, `merge_rightsize_pr` (ADR-0029's pattern): Hermes calls it only in a conversation, after the human's **Allow once** on the exact call; cron and alert sessions can't. The tool merges only an open, green PR by the App's bot with the `rightsize` label whose diff touches nothing but memory requests and limits at allow-listed paths, and it merges the head SHA it checked, so nothing pushed after the approval gets in.

## Consequences
- Easier: no thread waits a week for a right-size check; every change is a reviewed diff with its evidence, and a bad one is reverted by the same path.
- The App's key sits in two pods (the job and `lab-actions`), and the App can technically merge (GitHub has no "may open but not merge" permission on a free org). The guards: the job's code never merges; `lab-actions` merges only after a human Allow once and only a PR that passes its checks; the PR timeline is the audit log. Revisit with a paid plan (required reviewers) or a second human.
- Workloads not in the allow-list are reported but never changed, so Helm-managed apps (Alloy) need their values path added by hand first.
- CPU stays out of scope until the lab sees CPU pressure; memory is what limits the cluster.
- Revisit after eight weekly runs: if no PR needed changing before merge, consider auto-merging decreases under a cap (a new ADR).

## In a team or enterprise setting
This is the shape of most "autonomous" platform tooling that survives review: the agent proposes a diff with evidence, CI and a human (or a CODEOWNER) approve, GitOps applies. Tools like Kubecost, Goldilocks or the VPA recommender give the numbers; the PR bot is the part teams add. Required reviewers and a bot identity per repo replace this lab's "code never merges" convention.
