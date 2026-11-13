---
type: reference
title: How an AI agent runs a playbook
description: The protocol any AI agent follows when asked to run a playbook - guided, step by step, verified and recorded.
domain: meta
status: active
visibility: public
reuse: portable
created: 2026-10-20
updated: 2026-11-13
---

# How an AI agent runs a playbook

A playbook is started with one short prompt, for example:

> Run the playbook `playbooks/00-workstation-knowledge`.

From there the agent drives. The human answers questions and does the manual steps.

## Protocol

1. **Read first.** Read the playbook, `AGENTS.md`, and every ADR and open question it links. Don't act yet.
2. **Check where things stand.** For each step, run its *Verify* check first. Steps already done are reported and skipped, so a playbook can be re-run or resumed at any time.
3. **Open the run's journal entry.** Create (or reopen) `docs/journal/YYYY/YYYY-MM-DD-<playbook>.md` from `templates/journal.md` now, and append to it after every step. Don't leave it to the end.
4. **Confirm the manual prerequisites.** List any unchecked items from *Before you start* and wait until the human says they're done.
5. **For each step, in order:**
   1. **Explain** in two or three plain sentences what the step does and why it matters.
   2. **Ask** the step's *Questions*, one at a time, each with its recommended default. If an answer is already recorded in an ADR, state it and ask only whether it still holds.
   3. **Do** the step's *Actions*. Show commands before running anything destructive or anything that touches an external account.
   4. **Verify** with the step's check and show the result.
   5. **Record**: append to today's journal entry; write a `proposed` ADR for any new decision; update the how-to or reference pages the step names.
   6. **Pause** and ask whether to continue, unless the human said to run straight through.
6. **Manual steps** (marked 🧑): explain exactly what to click or do, then wait for "done" and verify.
7. **Export the session for review.** Remind the human to save the transcript to `.runs/` (git-ignored), e.g. `opencode export > .runs/<date>-<playbook>.json`, and to search it for `sk-or` and other secrets before sharing it. (`--sanitize` redacts every message and tool call, which leaves nothing to review.)
8. **Finish** with a summary: what changed, decisions made, what's next, and `blog: candidate` if the run produced something worth posting. Open a PR with all doc changes.

## Rules

- Never commit secrets, tokens, real public IPs or hostnames. Use placeholders.
- Never print a file or variable that may hold a secret (`.env`, `*.tfvars`, kubeconfigs, `/etc/rancher/k3s/config.yaml`, the age key in `$SOPS_AGE_KEY_FILE`, `~/.config/gh/hosts.yml`), a Kubernetes Secret's data (`kubectl get secret -o yaml|json|jsonpath`; use `kubectl describe secret`, which shows only key names and sizes) or a decrypted SOPS file (`sops decrypt`; the human uses `sops edit` in their own terminal): anything you print lands in the transcript and goes to the model provider. Check them without showing values (`cut -d= -f1 .env`, `grep -c '^KEY=' .env`), load them with `set -a; . ./.env; set +a`, and never paste a secret into a command line. `opencode.json` backs this rule with `read` and `bash` deny rules; copy it into every repo.
- **Human shell for secrets.** The human's shell is a second `ssh <repo>.devpod` (or the documented Docker fallback), not the agent's. Both shells share the folder: the agent creates the branch, the human only edits the SOPS file. Never tell the human to `git add`, `git commit --amend` or `git push -f`; after their edit, make a normal commit and push.
- **SOPS paste hygiene.** Move the cursor to the value with the arrow keys before pasting. A paste at line 1 becomes a YAML key, and SOPS encrypts values only, so the secret lands in plaintext in a public repo. After saving, the human checks `head -3` (first line `apiVersion: v1`) and `grep -c 'sk-or'` is `0`; the agent runs `scripts/check-secrets.sh`.
- **Never render or exec anything that decrypts.** No `kustomize build`, `ksops`, `sops decrypt`/`sops -d`, and no `kubectl exec` into a container that has secrets, not even to debug. Debug Argo CD sync failures from `kubectl -n argocd get application <app> -o yaml` status only; if a value is wrong, ask the human to re-edit. One carve-out for self-verification: the agent may prompt (`ask`) to run three narrow read-only Hermes CLI commands — `kubectl -n hermes exec deploy/hermes -c hermes -- hermes skills list`, `… -- hermes config get *`, `… -- hermes cron *`. `sh -c`/`bash`, any other exec target, `sops` and `ksops` stay denied.
- **Self-verify after every change.** After each merge that touches the cluster, the agent runs its own read-only verification (`kubectl get/describe/logs/rollout status`, plus the Hermes CLI commands above) and reports one consolidated result — don't ask the human to run checks you can run yourself.
- **Never a placeholder inside a secret value.** Give the human the command that generates it (`openssl rand -hex 32`) and a check that prints only its shape (prefix, length). A placeholder in angle brackets once became the real value.
- Every PR is opened with `--base main` (`gh pr create --base main`); delete setup branches after their merge, and check a merged PR's base with `gh pr view <n> --json baseRefName`.
- Doc edits in a shared checkout (the handbook) go on a branch or a `git worktree` right away, never uncommitted on `main`.
- If a run adds, removes or renames a handbook folder (top level, a `docs/` section or a domain), update the *Handbook layout* tree in `docs/meta/knowledge-system.md` in the same PR.
- Never push to `main`; open a PR. You may merge your own PRs with `gh pr merge --squash` once all required checks are green; never merge with failing or pending checks. Never use `gh pr merge --admin` (it bypasses the ruleset) and never push an empty commit to re-run CI; use `gh run rerun <run-id> --failed`. Wait for checks with `gh pr checks <n> --watch --fail-fast`, not `sleep` loops.
- If reality differs from the playbook (a UI changed, a command fails), fix the run, then propose an edit to the playbook in the same PR. Playbooks improve every time they run.
- If a command fails, read the error and diagnose before retrying. Never rerun the same command unchanged.
- If a step's answer changes an accepted ADR, stop and propose a superseding ADR instead of silently diverging.
- A step isn't done until its Verify passed. If a tool call errors (an edit that didn't apply, a command that failed), say so and fix it before reporting the step complete.
- Journal edits append. Never replace an existing section of the journal, even when updating "Next".
- Look a version up on its releases page before pinning it. Don't pin from memory.
- **Never retype an identifier.** Digests, commit SHAs, job and session IDs, UIDs and tokens are copied by a command from their source (registry header, `gh`, `kubectl -o jsonpath`), never typed from memory or from a context summary. After a context compaction, re-read every identifier from its source before using it. A digest carried through a summary once came back with seven characters scrambled and broke two pods.
- **A denied command is an answer.** If a permission rule denies or the human rejects a command, stop and ask; don't build a second route to the same result (a stub `ksops`, a downloaded binary, a token pulled from `gh`). The same rule binds Hermes (`SOUL.md`).
- **Cluster writes go through Git.** The agent reads the cluster freely, but changes it only through a PR that Argo CD syncs. The few direct writes a run needs (deleting a pod the agent's own PR broke, a throwaway test pod, an Argo CD refresh) are proposed with `ask`, and `kubectl apply` of anything is the human's (`bootstrap/install.sh`). Test pods go in `default` and are deleted in the same command (`kubectl run … --rm`).
- **Commit messages from a file.** Write the message with the edit tool and commit with `git commit -F <file>`. A message passed inline (`-m "$(cat <<EOF …)"`) is matched against the deny rules and gets blocked when it mentions a protected name such as `versions.env` or `ksops`.
- **One session per step group.** Start a fresh agent session every two or three steps and hand over through the journal (it holds state, IDs and next steps). A four-day single session (playbook 07: 11 compactions) loses detail at each compaction; the journal doesn't.
