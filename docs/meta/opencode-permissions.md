---
type: reference
title: OpenCode permissions policy
description: The shared ask/deny rules in opencode.json that gate what an agent can read and run, the tiers they follow, and how they are tested.
domain: meta
status: active
visibility: public
reuse: lab-specific
created: 2026-11-19
updated: 2026-11-19
related: [knowledge-system.md]
---

# OpenCode permissions policy

Every code repo (`handbook`, `workstation`, `homelab-infra`, `homelab-gitops`, `homelab-agents`) carries the same `opencode.json`. It gates the agent's `read`, `bash` and `external_directory` access so that a "self-serving" agent stays safe: it can read and explore freely inside the workspace, but must ask before anything destructive, and is hard-denied anything that touches secrets, rewrites history or bypasses the branch protection that guards `main`.

## Tiers

| Tier | Meaning | Examples |
|---|---|---|
| `allow` | runs without a prompt | `git status`, `git switch -c`, `git commit`, `gh pr view`, `grep`, `head`, `cat`, `find` |
| `ask` | runs only after the human approves | `git reset`, `git rebase`, `gh pr merge`, `kubectl apply`, `rm`, `docker`, `sudo`, `sleep 30` |
| `deny` | never runs | `git push --force`, `git rebase -i`, `gh pr merge --admin`, anything that names a secret file |

## Rule ordering

Rules are matched top-to-bottom and the **last match wins**. The file is therefore ordered deliberately:

1. broad `allow`s (baseline `*`, then git/gh/helper reads),
2. general `ask`s (destructive git, kubectl writes, `rm`/`sudo`/`docker`, long `sleep ??*`),
3. specific overrides (e.g. `git rebase origin/main*` allow, `git push --force-with-lease*` ask),
4. absolute `deny`s last (force-push, history rewrite, secret names, `kubectl exec`),
5. narrow read-only `ask`s after the `kubectl exec` deny — four exact `hermes` subcommands (`skills list`, `cron list`, `mcp list`, `--help`) that need to win over the blanket exec deny.

A `deny` placed after an `allow` always wins, which is what makes the secret and force-push guards hold. The same "last wins" rule makes tier 5 work: an `ask` placed **after** a `deny` wins, restoring a narrow, read-only path through the exec block.

## Secret-name denies

A deny matches any command line **containing** a protected name, not just a file read. Always denied:

- secret files: `*.env*`, `*tfvars*`, `*kubeconfig*`, `*.kube/config*`
- keys: `*sops-age*`, `*keys.txt*`, `*id_ed25519*`, `*id_rsa*`
- decryption: `*sops -d*`, `*sops --decrypt*`, `*ksops*`, `sops *`, `sops decrypt *`
- token/exfiltration: `gh auth token*`, `env`, `printenv`, `echo *GH_TOKEN*`
- secret-bearing exec: `kubectl exec*`, `kubectl cp*`

`read` adds its own file-level denies (`.env`, `.tfvars`, `kubeconfig`, `k3s.yaml`, `keys.txt`, `.sops-age/*`, `hosts.yml`), with `bootstrap/versions.env` allowed back in as a known-safe file.

## Force-push and history rewrites

- `git push --force` / `git push -f` → deny.
- `git push --force-with-lease` → ask (the sanctioned way to restart a run).
- `git rebase -i`, `git filter-branch`, `git filter-repo` → deny.
- `git push` to a ref named `main` (`git push*main*`, `git push*HEAD:main*`) → deny. Because `*` matches `/` as well as text, this also blocks any branch whose *name* contains `main`; that is accepted collateral of the guard.

## Protected `main`

`main` is protected by a ruleset (required status checks) on every repo. Repos whose ruleset enforces `required_status_checks` may `git push` to `origin` without a prompt, because the ruleset itself is the guard. `workstation` has a protect-`main` ruleset but no required checks, so its `opencode.json` keeps `git push` as `ask`; when a required check (gitleaks) is added, the `push origin*` allow is switched on.

## Filesystem confinement

`external_directory` allows only `*` under the workspace root — the concrete entries are `/workspaces/**`, `/knowledge/handbook/**` and `/tmp/agent/**`, with everything else `ask`. Paths outside the workspace (e.g. `~/.ssh`, `/etc`) are not silently readable, so an agent can't pull credentials or host configs it should not.

## Test matrix

The policy is verified in a fresh session. Expected results for the key cases:

| Command | Result |
|---|---|
| `read …/triage.py` | allow |
| `gh pr view 1 --json title \| head -5` | allow |
| `git switch -c test/perm && git commit --allow-empty -m test` | allow |
| `git rebase origin/main` | allow |
| `grep -r KEY …/.env` | deny |
| `git push origin HEAD:main` | deny |
| `git push --force` | deny |
| `git push --force-with-lease origin main` | deny |
| `gh pr merge 1 --admin` | deny |
| `git rebase -i origin/main` | deny |
| `git reset --hard` | ask |
| `sleep 30` | ask |
| `sleep 5` | allow |
| `kubectl -n hermes exec deploy/hermes -c hermes -- hermes skills list` | ask |
| `kubectl -n hermes exec deploy/hermes -c hermes -- hermes config get x` | deny |
| `scripts/image-digest.sh ghcr.io/ssaav5-ai-labs/job-search sha-a1e18e8` | allow |

## Keeping the copies in sync

There is one policy, copied into each repo, with two narrow exceptions: `workstation` keeps `git push` as `ask` (no required status checks on `main`), and `homelab-gitops` adds `scripts/image-digest.sh *` as `allow` (the sanctioned tool for "never retype a digest"). When the policy changes, update all five repos, each in its own PR, so the guard never drifts from the documented behavior.
