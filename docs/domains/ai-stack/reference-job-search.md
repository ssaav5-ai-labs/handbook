---
type: reference
title: Job-search agent reference
description: The job-search MCP server and drafting crew in homelab-agents, deployed from homelab-gitops into the career namespace, with Hermes in Slack as the front end and the daily email feed.
domain: ai-stack
tags: [job-search, crewai, mcp, hermes, slack, career-vault, imap, cronjob]
status: draft
created: 2026-11-19
updated: 2026-11-19
visibility: public
reuse: lab-specific
blog: none
---

# Job-search agent reference

The job-search agent scores roles pasted into `#job-search`, drafts CV summaries and cover notes into the private `career-vault`, and posts a daily digest of job-alert emails. See [design-job-search.md](design-job-search.md) for the machinery and [ADR-0036](../../decisions/0036-job-search-agent-finds-human-applies.md) for the decisions.

## Daily feed

The feed is the step 9 CronJob: it reads a dedicated job-alerts mailbox, filters and scores the alerts, and writes a daily digest that Hermes posts to Slack each morning.

| Piece | Value |
|---|---|
| CronJob | `job-triage` in `career` (`python -m job_search.triage` from the job-search image) |
| Schedule | `0 7 * * *` (07:00 Europe/Dublin) |
| Hermes post | `job-search-daily` at `30 7 * * 1-5` (07:30) → `#job-search` |
| Gate | `JOB_TRIAGE_ENABLED=true` (off by default: logs "job triage disabled" and exits 0) |
| Threshold | 70 (`shortlist_threshold` in `profile.md`) |
| Cap | 5 (`daily_cap`) |
| Digest | `job-search/digests/YYYY-MM-DD.md` in career-vault |
| Concurrency / deadline | `concurrencyPolicy: Forbid`, `activeDeadlineSeconds: 600` |

- **Mailbox:** read-only IMAP through the egress proxy —
  `IMAP_PROXY=http://egress-proxy.career.svc.cluster.local:3128`. `triage.py` opens a
  `CONNECT imap.gmail.com:993` tunnel (tinyproxy `ConnectPort 993` + `^imap\.gmail\.com$`
  filter), then wraps it in TLS. Fetches with `BODY.PEEK`, so alerts stay unread.
- **Credentials:** its own Secret `job-triage` (`IMAP_HOST`, `IMAP_USER`,
  `IMAP_APP_PASSWORD`), separate from the `job-search` Secret, plus the write deploy key
  to commit the digest. `JOBS_GATEWAY_KEY` for scoring comes from the `job-search` Secret.
- **Flow:** allowed senders (`jobalerts-noreply@linkedin.com` by default), deterministic
  rules (location, seniority, exclusions, already-seen), then one `jobs-fast` score per
  survivor. The digest lists what the rules skipped and the shortlist (score ≥ threshold).
