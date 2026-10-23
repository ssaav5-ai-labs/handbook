---
type: howto
title: Create a branch ruleset for the handbook
description: Reproducible steps to protect main with a PR requirement, a required status check, and no force pushes, on a free public repo.
domain: github
tags: [github, rulesets, branch-protection]
status: active
created: 2026-10-23
updated: 2026-10-23
visibility: public
reuse: portable
related: [../index.md, ../../decisions/0004-github-free-org-public-repos.md]
blog: none
---

# Create a branch ruleset for the handbook

## Why

Nothing reaches `main` without a PR and a passing `build` check. On the free plan, **organization-level rulesets require a Team plan**, so we use a **repository-level ruleset** — free on public repos, same effect.

## Prerequisites

- `gh` authenticated with `repo` and `admin:org` scopes.
- The `build` job exists in `.github/workflows/docs.yml` (the status check context must match the job key exactly).

## Steps

1. Write the ruleset to a JSON file:

```json
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "rules": [
    { "type": "pull_request" },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false, "required_status_checks": [{ "context": "build" }] } },
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" }
  ]
}
```

2. Create it:

```bash
gh api --method POST repos/ssaav5-ai-labs/handbook/rulesets --input ruleset.json
```

3. List rulesets to confirm:

```bash
gh api repos/ssaav5-ai-labs/handbook/rulesets --jq '.[].name'
```

## Verify

- `gh api repos/ssaav5-ai-labs/handbook/rulesets/<id> --jq '.current_user_can_bypass'` returns `"never"`.
- A direct `git push` to `main` is rejected; changes land only through a PR that passes `build`.

## Undo / rollback

```bash
gh api --method DELETE repos/ssaav5-ai-labs/handbook/rulesets/<id>
```

## Related decisions

- [ADR-0004](../../decisions/0004-github-free-org-public-repos.md) — free org, public repos, required approvals 0.
