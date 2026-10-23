---
type: playbook
title: Set up the GitHub organization and publish the handbook
description: Creates the lab GitHub organization with enterprise-style settings and publishes this handbook as a public site.
domain: github
tags: [github, governance, docs-as-code]
status: draft
created: 2026-10-20
updated: 2026-10-23
visibility: public
reuse: portable
repo: handbook
depends_on: [../00-workstation-knowledge]
related:
  - ../../docs/decisions/0004-github-free-org-public-repos.md
  - ../../docs/decisions/0003-central-handbook-repo.md
  - ../../docs/decisions/0006-local-repo-layout.md
blog: candidate
---

# Set up the GitHub organization and publish the handbook

## What you'll have at the end
A free GitHub organization that's configured like a company's: two-factor authentication required, teams, branch rules, security scanning, and automated checks. This handbook lives in it as a public repo, and its site is live on GitHub Pages. Every later playbook builds on this.

## Before you start 🧑
- [ ] Two-factor authentication is on for your GitHub account (a passkey is best).
- [ ] Playbook 00 is finished (handbook dev container running, org name chosen).
- [ ] Inside the handbook dev container you've run `gh auth login` with scopes `repo`, `workflow` and `admin:org`.

## Kick it off
> Run the playbook `playbooks/01-github-foundation`.

## Steps

### 1. Confirm names
**Why:** The org name was chosen in playbook 00; confirm it exists or is still available before creating anything.
**Questions:** Custom domain for the site now or later (recommended: later)?
**Actions:** Check `gh api orgs/ssaav5-ai-labs` — if it returns the org, skip to step 3; if 404, the name is free and step 2 creates it.
**Verify:** `gh api orgs/ssaav5-ai-labs --jq .login` prints the name.

### 2. Create the organization 🧑
**Why:** GitHub only lets you create a Free organization from the website.
**You do:** github.com → **+** → **New organization** → **Free** → enter the chosen name → owned by "My personal account".
**Verify:** `gh api orgs/ssaav5-ai-labs --jq .login` prints the name.

### 3. Create the repo and push
**Why:** Gets the handbook under version control in the org.
**Questions:** None (public visibility comes from ADR-0004).
**Actions:** `gh repo create ssaav5-ai-labs/handbook --public --source . --push`. Create `workstation` (public) and `career-vault` (private, under your personal account) empty; the container can't see those folders, so 🧑 you push them from PowerShell.
**Before pushing `workstation` 🧑:** it holds `gateway/.env` with the gateway master key and the OpenRouter key, and it goes public. In PowerShell, in the workstation folder: `git check-ignore gateway/.env` must print the path, and `git log -p | Select-String "sk-or"` must print nothing. Only then `git remote add origin https://github.com/ssaav5-ai-labs/workstation.git` and `git push -u origin main`.
**Verify:** `gh repo view ssaav5-ai-labs/handbook` succeeds.
**Record:** Journal entry.

### 4. Organization settings
**Why:** Mirrors what an enterprise enforces centrally.
**Questions:** Teams to create (recommended: `platform`, `sre`).
**Actions:** Require 2FA for members; set base permission to Read; create the teams; add a `CODEOWNERS` file that assigns `docs/decisions/` to `@ssaav5-ai-labs/sre`.
**Verify:** `gh api orgs/ssaav5-ai-labs --jq .two_factor_requirement_enabled` is `true`; `gh api orgs/ssaav5-ai-labs/teams --jq '.[].slug'` lists the teams.
**Record:** Update `docs/domains/github/index.md`.

### 5. Branch ruleset
**Why:** Nothing reaches `main` without a PR and passing checks, which is the change control companies rely on.
**Questions:** Required approvals (recommended: 0, because you can't approve your own PR; automated review stands in).
**Actions:** Create a **repository-level** ruleset on the default branch (org-level rulesets need the Team plan, but repo rulesets are free on public repos): require a PR, require the `build` status check, block force pushes and deletions, require linear history, and keep the bypass list empty.
**Verify:** A direct `git push` to `main` is rejected.
**Repeat per repo:** a repository ruleset covers one repo, so apply the same ruleset to `workstation` once it has a CI job to require (see the how-to), and to every new public repo.
**Record:** Add a how-to page, `docs/domains/github/howto-rulesets.md`.

### 6. Security features
**Why:** Free on public repos and expected in any enterprise.
**Actions:** Turn on Dependabot alerts and updates, secret scanning, and push protection. On public repos the dedicated secret-scanning endpoints return 404; use `gh api -X PATCH repos/<org>/<repo>` with a `security_and_analysis` body instead. In CI, `gitleaks/gitleaks-action` needs a paid license for organization repos, so run the pinned gitleaks CLI instead (as `docs.yml` does).
**Verify:** `gh api repos/ssaav5-ai-labs/handbook --jq .security_and_analysis` shows them enabled.

### 7. Publish the site
**Why:** Gives you a public portfolio URL and lets agents fetch `llms.txt`.
**Actions:** Set Pages to deploy from GitHub Actions; open a PR so the `docs` workflow runs; merge it.
**Verify:** `https://ssaav5-ai-labs.github.io/handbook/` and `/llms.txt` load.
**Record:** Accept ADRs 0001-0006 by setting `status: accepted` in this PR; update the decision log.

## When it's done
- Docs updated: `docs/domains/github/`, decision log, journal.
- 🧑 Push `workstation` (after the `.env` check in step 3) and `career-vault` from PowerShell, then give `workstation` the same security settings.
- Next playbook: 02 local AI automation (Hermes).

## Video
Not recorded yet.
