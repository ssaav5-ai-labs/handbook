---
type: adr
title: Let an agent find and draft job applications, never submit them; the human applies
description: A small job-search crew reads job-alert emails, scores roles against a private profile and drafts tailored notes into the private career vault; Hermes in Slack is the front end; nothing touches LinkedIn or submits an application, and every write needs a human "Allow once".
domain: career
tags: [job-search, agents, crewai, hermes, mcp, approvals, privacy, linkedin]
status: proposed
created: 2026-11-13
updated: 2026-11-13
visibility: public
reuse: portable
related: [0005-private-career-vault.md, 0008-vendor-neutral-ai-stack.md, 0020-secrets-in-git-with-sops-age-ksops.md, 0023-hermes-on-k3s-pod-as-sandbox.md, 0025-gateway-virtual-keys-with-postgres.md, 0027-crewai-crews-as-mcp-tools.md, 0028-agent-read-access-through-upstream-mcp-sidecars.md, 0029-agent-writes-only-through-an-approval-gated-mcp-server.md, ../domains/ai-stack/design-job-search.md, ../patterns/agent-finds-human-acts.md]
supersedes: []
superseded_by: []
blog: candidate
---

# 0036. Let an agent find and draft job applications, never submit them; the human applies

## Context
I'm looking for SRE management roles. Reading job alerts, judging fit and tailoring a CV summary and cover note for each good match takes hours a week, and it's the kind of work the lab's agents already do for alerts: read, judge, draft, ask a human.

"Auto-apply" tools exist, and I considered them. Three things rule them out:

- **LinkedIn's User Agreement bans bots, scrapers and automated access**, and LinkedIn restricts accounts for it. My LinkedIn profile is part of how this work becomes visible to employers, so it isn't worth risking.
- **Volume hurts at this level.** Hiring managers for SRE leadership roles spot generic applications; a few tailored ones beat hundreds of sprayed ones.
- **An agent filling in forms speaks for me.** Salary, right to work, notice period, "years of X": a wrong answer is a misstatement under my name that I can't take back.

Constraints: vendor-neutral and cheap (ADR-0008), reuse what's running (gateway, Hermes, CrewAI-as-MCP, Argo CD, SOPS), and private data stays private (ADR-0005): the profile, CV, drafts and the list of roles live only in the private `career-vault`; the public repos get code and a sanitized pattern.

## Options considered
1. **Commercial auto-apply service or browser bot**: fastest to "volume", but breaks LinkedIn's terms, risks the account, and answers questions in my name. Rejected.
2. **Scrape LinkedIn search results, human applies**: better outcome, same terms and account risk. Rejected.
3. **Do it all by hand**: safe, slow, and teaches nothing new.
4. **Agent finds, scores and drafts from sources I'm allowed to automate; I review and apply myself**: job-alert emails I already receive (and public ATS job APIs) as input, a small crew behind the lab's MCP pattern, Hermes in Slack as the front end, drafts in the career vault.

## Decision
Option 4. The agent finds and drafts; I decide and apply.

- **Inputs:** job-alert emails (LinkedIn and other boards) forwarded to a dedicated mailbox the agent reads read-only, plus roles I paste into Slack. For shortlisted roles, the full description comes from the employer's public ATS job API (Greenhouse, Lever, Ashby) or from me pasting it. **Nothing in the lab connects to linkedin.com**; the NetworkPolicy egress allow-list enforces that. LinkedIn Premium Career (which I'm taking) changes nothing here: it has no API for job seekers, so it improves the alerts that reach the mailbox, and its own job-match and applicant insights are something I read by hand in the review step.
- **Never submits:** no tool can fill in or submit an application, message a recruiter, or answer salary, right-to-work or notice questions. Drafts leave those as placeholders for me.
- **Where it runs:** a `job-search` MCP server in its own namespace `career`, built in `homelab-agents` and deployed by Argo CD like the SRE crews (ADR-0027), but in a separate pod with its own credentials (ADR-0028: one credential per container). A daily CronJob does the deterministic part (read mail, filter, score, write the day's digest).
- **Front end:** Hermes in a private `#job-search` Slack channel. A daily Hermes cron posts the top matches using a read-only tool; I reply "draft 2" or "applied 3". Tools that write to the vault are not read-only, so Hermes asks "Allow once" for each (ADR-0029's approval model); unattended sessions can't call them.
- **Private data:** the profile, scoring criteria, digests, role files and drafts are Markdown with frontmatter in `career-vault/job-search/`, which is also the status tracker (Obsidian shows it as a table). Mailbox and vault credentials are SOPS-encrypted in `homelab-gitops`. Its gateway virtual key `jobs` has a small budget, uses providers that don't train on or keep prompts, and doesn't send prompt or completion text to Langfuse Cloud (cost and latency only).
- **Truthfulness guard:** every draft goes through a checker that lists each claim and the vault line that supports it; unsupported claims are flagged at the top of the draft, not silently kept.

## Consequences
- A few minutes a day in Slack replaces reading alerts by hand, and every application I send is one I chose and read.
- The input is only as good as the alerts: tuning LinkedIn's alert searches matters more than tuning prompts. Alert emails are short, so full descriptions sometimes need a paste from me.
- One more pod (~256 Mi), a CronJob, a mailbox and a second private-repo credential to look after. The vault deploy key can write anywhere in `career-vault`; the server only writes under `job-search/`, and Git history makes any write reversible.
- My CV text goes to model providers through OpenRouter. Using no-retention providers limits that; switching the `jobs` aliases to the `local` model removes it when the lab can run one.
- Approval fatigue (ADR-0029) applies: one "Allow once" per draft is the deliberate "yes, I want this role" tap; skip needs no tap at all.
- Revisit if LinkedIn offers an official, permitted API for job seekers, or if volume makes a second channel (company watchlists via ATS APIs) worth adding.

## In a team or enterprise setting
This is the shape for any agent that acts under a person's name (sales outreach, recruiting, vendor email, customer replies): the agent gathers and drafts from sources it is allowed to automate, a human sends, every outward action is a deliberate, approved step, and claims are traced back to a source. Terms of service and data protection are design inputs, enforced in the network and the tool list, not left to the prompt.
