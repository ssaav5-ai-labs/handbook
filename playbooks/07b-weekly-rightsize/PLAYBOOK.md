---
type: playbook
title: Weekly right-sizing by pull request, opened by an agent and merged by you
description: Turns the crews' Monday capacity proposals into one pull request in homelab-gitops through a GitHub App scoped to that repo, checks last week's merged change and proposes a revert if it hurt, and links the PR in Hermes' Monday report, so no right-size check waits in a thread.
domain: ai-stack
tags: [right-sizing, gitops, github-app, cronjob, crewai, mcp, hermes, argocd, sops]
status: draft
created: 2026-11-13
updated: 2026-11-13
visibility: public
reuse: portable
repo: homelab-agents
depends_on: [../07-sre-crews]
related:
  - ../../docs/decisions/0019-gitops-with-argo-cd-app-of-apps.md
  - ../../docs/decisions/0027-crewai-crews-as-mcp-tools.md
  - ../../docs/decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md
  - ../../docs/decisions/0037-weekly-right-sizing-by-pull-request.md
  - ../../docs/domains/ai-stack/reference-sre-crews.md
  - ../../docs/domains/ai-stack/runbook-sre-crews.md
blog: candidate
---

# Weekly right-sizing by pull request, opened by an agent and merged by you

## What you'll have at the end
Every Monday at 07:30, before Hermes posts the capacity report, a small CronJob in `sre` asks the crews for this week's proposals, keeps the ones worth a change, and opens **one pull request** in `homelab-gitops` with the new memory requests and limits and the evidence behind each. At 08:00 Hermes' report links that PR. Reply "merge it" in the thread, check the tool call Slack shows you, tap **Allow once**, and Hermes merges it through `lab-actions`; Argo CD applies it. (You can still merge or close it in GitHub.) The next Monday the job first checks last week's merged change: if a workload it touched was `OOMKilled` or restarted since, it opens a **revert PR** instead of new changes.

```
Mon 07:30  rightsize CronJob ──MCP──▶ crews: capacity_proposals (read-only, deterministic)
                  │
                  └──GitHub App (homelab-gitops only)──▶ PR "rightsize 2026-11-23"  ──CI──▶ you merge ──▶ Argo CD
Mon 08:00  Hermes cron ──▶ #homelab-alerts: capacity report + "Open right-size PR: #N"
           you: "merge it" ──▶ Hermes ──▶ lab-actions: merge_rightsize_pr(N)  [Slack: Allow once]
```

No LLM touches the numbers or the diff: the proposals come from the same code that has been spot-checked since playbook 07 step 7. The job holds a GitHub credential and nothing else; it can't read the cluster or Grafana itself, and it never merges. Merging is a `lab-actions` tool, so it gets the same gate as a restart: your **Allow once** on the exact call, and a tool that refuses anything but a green, bot-authored `rightsize` PR touching only allow-listed resources ([ADR-0037](../../docs/decisions/0037-weekly-right-sizing-by-pull-request.md)).

## Before you start 🧑
- [ ] Playbook 07 is through step 9 (crews, capacity report, `lab-actions` and drills verified). Its step 10 right-size check, and playbook 05's pending 7-day re-check, are handed to this playbook's first PR.
- [ ] The playbook 07 run review is merged (`RUNNING.md` rules on identifiers and cluster writes, the `opencode.json` template copied into `homelab-gitops` and `homelab-agents`).
- [ ] **`main` rulesets without bypass** in `homelab-gitops`: Settings → Rules → Rulesets → the `main` ruleset → *Bypass list* is empty, and *Require status checks* lists `ci`. Without this, an org admin token (yours, and anything acting as you) can merge around the checks.
- [ ] You can create a GitHub App in the org (org owner).

## Kick it off
In the `homelab-gitops` container, a fresh session:
```bash
opencode
```
> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/07b-weekly-rightsize`.

Keep your second shell (`ssh homelab-gitops.devpod`) for the `sops edit`s in steps 6 and 7. The agent works on `homelab-agents` in `/tmp/agent/homelab-agents` and on `homelab-gitops` in the container's folder, as in playbook 07.

## Steps

### 1. Scope and rules
**Why:** The job changes production manifests every week, so what it may touch and by how much is decided once, here, and written down.
**Questions:**
- When. Default **Mondays 07:30** in the same time zone as the capacity report (it must finish before Hermes' 08:00 run).
- Threshold. Default **change ≥ 15 % and ≥ 32 Mi** on the request, so weekly noise doesn't open PRs.
- Rule. Default **playbook 05 step 9's rule, unchanged** (request from the 7-day peak with headroom; limit ≥ 2 × request and ≥ peak + 128 Mi), the same code `weekly_capacity_report` uses.
- Which workloads. Default: everything playbooks 05 to 07 right-sized by hand: the plain manifests (`sre-crews` and its sidecars, `lab-actions`, `hermes`, `litellm`, `postgres`) and playbook 05's monitoring stack, whose Helm values paths (Alloy, kube-state-metrics, the Alloy operator) the agent maps by hand in step 3. Anything else stays out until it's added to the list.
- CPU. Default **no**: memory is what limits the lab.

**Actions:** The agent reads `reference-sre-crews.md` (the rule) and the current resources of each candidate (`kubectl get deploy -o jsonpath`), and lists where each one's resources are defined in `homelab-gitops` (file and YAML path).
**Verify:** The human agreed the list, threshold and schedule.
**Record:** Journal entry `docs/journal/YYYY/YYYY-MM-DD-playbook-07b.md` with the answers.

### 2. A GitHub App for `homelab-gitops` only 🧑
**Why:** A personal token would act as you, an org owner, on every repo. An App is its own identity, installed on one repo, with exactly two permissions, and its tokens expire after an hour.
**You do:**
1. Org settings → Developer settings → GitHub Apps → **New GitHub App**. Name `homelab-rightsize`; homepage the handbook URL; **Webhook: off**.
2. Repository permissions: **Contents: Read and write**, **Pull requests: Read and write**, Metadata: Read (automatic). Nothing else. *Where can this app be installed:* only this account.
3. Create, note the **App ID**. *Generate a private key*: a `.pem` downloads. Save it in your password manager as "homelab-rightsize GitHub App key" (a secure note), then delete the download.
4. *Install App* → the org → **Only select repositories** → `homelab-gitops`. The URL ends in the **installation ID**; note it.
5. In `homelab-gitops`: Issues → Labels → new label `rightsize`.

**Verify:** The agent checks (no secret involved): `gh api /orgs/ssaav5-ai-labs/installations --jq '.installations[] | select(.app_slug=="homelab-rightsize") | {repository_selection, permissions}'` shows `selected` and only `contents`, `metadata`, `pull_requests`; `gh api repos/ssaav5-ai-labs/homelab-gitops/rulesets` → the `main` ruleset's `bypass_actors` is empty.
**Record:** `reference-sre-crews.md`, new section *Right-sizing PRs*: the App's name, permissions, installation scope, where its key lives (not the key).

### 3. The allow-list in `homelab-gitops`
**Why:** The job edits only what this file names, at the exact path it names, so a new app is never right-sized by surprise and a YAML refactor can't make it edit the wrong block.
**Actions:**
- `platform/rightsize-targets.yaml`:
  ```yaml
  # Workloads the weekly rightsize job may change (ADR-0037). One entry per container.
  targets:
    - namespace: llm-gateway
      workload: litellm          # Deployment name
      container: litellm
      file: platform/llm-gateway/deployment.yaml
      path: spec.template.spec.containers[name=litellm].resources
    # … one entry per agreed workload/container
  ```
- `scripts/check-rightsize-targets.py` (in `ci`): every `file` exists and every `path` resolves to a mapping with `requests.memory` and `limits.memory`; no two entries share a path.

**Verify:** `ci` green on the PR; the script fails when you break one path on purpose (test in the PR's first commit, fixed in the second).
**Record:** Journal: the list.

### 4. A structured proposal tool on the crews server
**Why:** The report is text for people; the job needs the same numbers as data. One function computes both, so the PR and the Slack report can't disagree.
**Actions (`homelab-agents`):**
- `capacity_proposals()` in the crews MCP server, `readOnlyHint: true`: returns JSON per workload container: `namespace`, `workload`, `container`, `node`, `request_mi`, `limit_mi`, `peak_7d_mi`, `proposed_request_mi`, `proposed_limit_mi`, `restarts_7d`, `last_oomkilled_at`, and `generated_at`. Built from the same functions as `weekly_capacity_report` (peaks grouped by workload, totals in code). On a fetch failure it returns `{"error": "<which>"}`, never partial data.
- `weekly_capacity_report` gains one line at the end: the open PR labelled `rightsize` in `homelab-gitops`, read from GitHub's public API (`GET /repos/ssaav5-ai-labs/homelab-gitops/pulls?state=open` filtered by label; no token: the repo is public), or nothing if none is open.
- Tests: the JSON matches the text report on the same fixture; an error in either fetch gives `{"error": …}`; the PR line with zero, one and two open PRs.
- PR, `ci`, merge; the new digest **copied by command** from the registry into `versions.env` and the Deployment (`RUNNING.md`), PR in `homelab-gitops`.

**Verify:** In the crews logs after the pod restarts, a `tools/list` from Hermes includes `capacity_proposals`; 🧑 DM Hermes "Call capacity_proposals and show me the raw result": numbers match Monday's report.
**Record:** `reference-sre-crews.md`: the tool.

### 5. The job
**Why:** The logic that turns proposals into a PR, with every rule from step 1 in code and tests, before it gets a credential.
**Actions (`homelab-agents`, same image, entry point `python -m sre_crews.rightsize`):**
1. Get an installation token: a JWT signed with the App key (`PyJWT` + `cryptography`, pinned), then `POST /app/installations/<id>/access_tokens`. Never log the token.
2. If an open PR labelled `rightsize` exists: log "PR #N still open", exit 0. One PR at a time.
3. **Check last week first.** Find the last merged `rightsize` PR. For each container it changed, look at `capacity_proposals`' `last_oomkilled_at` and `restarts_7d`: if a container was `OOMKilled` or restarted after the merge time, build a **revert PR** for those containers (back to the values before that PR, read from its diff) and stop.
4. Otherwise call `capacity_proposals` over MCP (`http://sre-crews.sre.svc:8000/mcp`, bearer `CREWS_MCP_TOKEN`, `Host` header as in playbook 07 step 5). An `error` → exit 1 (the job fails, `RightsizeJobFailed` fires).
5. Keep proposals for targets in `platform/rightsize-targets.yaml` (fetched from `main` through the API) that pass the threshold. None left → log "no change this week", exit 0.
6. Edit each file at its path with `ruamel.yaml` (keeps comments and order), create branch `rightsize/<YYYY-MM-DD>` and commit through the contents API, open the PR (title `rightsize: <date>`, label `rightsize`) with a body: the table (container, old → new request and limit, 7-day peak, restarts), the rule and threshold, "generated by the rightsize job from `capacity_proposals` at `<generated_at>`", and how to revert (close, or revert the merge commit).
7. `DRY_RUN=true`: do everything up to 6 except writing; print the diff and the PR body.

Tests (fixtures, no network): open PR exists → no action; no change → no PR; a change under the threshold → none; a non-listed workload → never touched; a merged PR followed by an `OOMKilled` → revert PR with the old values; YAML comments survive an edit; the token never appears in logs (assert on captured output).
**Verify:** `ci` green; the tests above listed in the PR.
**Record:** Journal: the test list.

### 6. The CronJob on the cluster
**Why:** Same image, a different pod with a different credential: the GitHub key never sits next to the Kubernetes or Grafana tokens.
**Actions (`homelab-gitops`, `platform/sre-crews/`):**
- ServiceAccount `rightsize`, `automountServiceAccountToken: false` (it needs no Kubernetes API).
- Secret `rightsize` (new `rightsize-secret.enc.yaml`): `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`, `CREWS_MCP_TOKEN` (the existing crews token).
- CronJob `rightsize`: `schedule: "30 7 * * 1"`, `timeZone: <your time zone>`, `concurrencyPolicy: Forbid`, `backoffLimit: 0`, `activeDeadlineSeconds: 300`, `successfulJobsHistoryLimit: 4`, `failedJobsHistoryLimit: 4`, `DRY_RUN=true` for now; restricted security context as in playbook 07 step 5; requests `10m`/`96Mi`, limit `256Mi`.
- NetworkPolicy: egress DNS, `app: sre-crews` TCP 8000, and TCP 443 to anything outside RFC 1918 (GitHub); no ingress. The crews' ingress policy also admits `app: rightsize` on 8000.
- `platform/monitoring/rules.yaml`: `RightsizeJobFailed`: `kube_job_status_failed{namespace="sre", job_name=~"rightsize-.*"} > 0` for 5m, warning.
- 🧑 In your shell, after the agent pushed the branch with a template (values `REPLACE_ME`): `sops encrypt -i platform/sre-crews/rightsize-secret.enc.yaml`, then `EDITOR=nano sops edit` it. The two IDs quoted (`"123456"`); the key as a YAML block: `GITHUB_APP_PRIVATE_KEY: |` then the PEM's lines indented two spaces (paste from the password manager with the cursor on the line below the key name). Save. Check the shape without printing it: `grep -c 'BEGIN' platform/sre-crews/rightsize-secret.enc.yaml` is `0` (encrypted) and `grep -oE 'GITHUB_APP_PRIVATE_KEY: ENC\[.{0,40}' …` shows `ENC[`. "done".
- PR, `ci`, squash-merge, refresh `root`.

**Verify:** `kubectl -n sre get cronjob rightsize` shows the schedule and time zone; 🧑 run it once: `kubectl -n sre create job rightsize-manual-1 --from=cronjob/rightsize`; the agent reads `kubectl -n sre logs job/rightsize-manual-1`: the dry-run diff and PR body, no token in the output, exit 0. Delete the job (🧑, or the agent with `ask`).
**Record:** `reference-sre-crews.md`: the CronJob, its policy, the alert.

### 7. Merge from Slack, behind your "yes"
**Why:** A PR you approve from your phone in two taps keeps you in the loop without opening GitHub. The merge is a write, so it lives where writes live ([ADR-0029](../../docs/decisions/0029-agent-writes-only-through-an-approval-gated-mcp-server.md)): a `lab-actions` tool that Hermes can only call after your **Allow once**, and that cron or alert sessions can't call at all.
**Actions:**
- `homelab-agents`, `lab_actions.py`: tool `merge_rightsize_pr(pr_number, reason)`, `destructiveHint: true`. Before merging it checks, through the GitHub API with an App installation token, and refuses with the reason if any fails: the PR is open against `main`; its author is `homelab-rightsize[bot]`; it carries the `rightsize` label; every check run on its head commit is `success`; every changed file is listed in `platform/rightsize-targets.yaml` on `main`; and, parsing the old and new YAML, nothing changed except `requests.memory`/`limits.memory` at the listed paths. It then squash-merges **with the head SHA it checked** (`PUT …/merge` with `sha`), so a commit pushed after your approval makes the merge fail instead of slipping in. It logs the PR, the SHA and the reason. Tests: each refusal; a stale SHA; the token never logged.
- `homelab-gitops`: the `lab-actions` Secret gains `GITHUB_APP_ID`, `GITHUB_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY` (🧑 `sops edit`, the same values as step 6); its NetworkPolicy gains egress TCP 443 outside RFC 1918; Hermes' managed config: `lab_actions.tools.include: [restart_workload, merge_rightsize_pr]`; `SOUL.md`: Hermes may offer `merge_rightsize_pr` for an open `rightsize` PR when you ask, and never for any other PR.
- The capacity report's PR line ends with "Reply *merge it* in this thread to merge." (the cron session itself can't call the tool, by design).
- PR, `ci`, merge, new digest by command, 🧑 restart Hermes by deleting its pod.

**Verify:**
- 🧑 DM Hermes: "Merge PR #<any open non-rightsize PR>". The approval card shows the call; **Allow once**; the tool refuses (not a `rightsize` PR); nothing merges.
- `kubectl -n sre logs deploy/lab-actions` shows the refused call with its reason.

**Record:** `reference-sre-crews.md`: the tool and its checks. `howto-add-agent-action.md`: this is the second action, a worked example of adding one.

### 8. The first real PR, merged from Slack 🧑
**Why:** A proposal you'd merge is the proof. This PR is also playbook 07's step 10 right-size and playbook 05's 7-day re-check.
**Actions:** The agent opens a PR setting `DRY_RUN=false`; merge; 🧑 `kubectl -n sre create job rightsize-manual-2 --from=cronjob/rightsize`.
**Verify:**
- A PR `rightsize: <date>` by `homelab-rightsize[bot]`, label `rightsize`, `ci` green, body with the table. 🧑 Check two rows against Monday's Slack report and `kubectl get deploy -o jsonpath='{…resources}'`.
- 🧑 At 08:00 (or after a manual `hermes cron run` of the capacity job) the report links the PR. Reply "merge it", check the card shows `merge_rightsize_pr` with that PR number, **Allow once** (or close the PR and record why). Argo CD syncs; the changed pods restart with the new resources; no `OOMKilled` in the next 10 minutes.
- A second manual run (`rightsize-manual-3`) logs "no change this week" or "PR #N still open", and opens nothing.

**Record:** Journal: the PR, what you changed in it (ideally nothing), per-node requests before and after.

### 9. Drills
**Actions:**
- **No bypass.** `gh api repos/ssaav5-ai-labs/homelab-gitops/rulesets/<id> --jq '.bypass_actors'` is `[]`; record it.
- **Crews down.** Run the job while the crews pod restarts (🧑 `kubectl -n sre delete pod -l app=sre-crews`, then at once `kubectl -n sre create job rightsize-manual-4 --from=cronjob/rightsize`): it exits 1 with the MCP error, opens nothing, and `RightsizeJobFailed` fires within 10 minutes, then resolves when the job is deleted.
- **Merge guard.** After step 8's merge, ask Hermes to merge it again ("merge PR #N"): refused (not open). Push a commit to a test branch labelled `rightsize` by hand: refused (author). Ask from a cron-style prompt is covered by Hermes' `cron_mode: deny` (playbook 07 step 9).
- **Revert path.** Covered by step 5's test; mark the live revert **untested** until a real one happens, and add a runbook line for it.
- **Turn it off.** `suspend: true` on the CronJob in a PR, check `kubectl -n sre get cronjob rightsize -o jsonpath='{.spec.suspend}'` is `true`, then revert that PR.

**Verify:** All apps `Synced`/`Healthy`; no open drill PRs; the alert resolved.
**Record:** Journal: each drill's result.

### 10. Finish
**Actions:** `runbook-sre-crews.md`, section *Right-sizing PRs*: job failed (logs, the MCP error, an expired or revoked App key), a wrong PR (close it; fix the rule or the allow-list), a revert PR (merge it, then look at why), rotating the App key (generate a new one, `sops edit` both Secrets, delete the old one in the App settings), a merge refused (the tool's reason; fix the PR or merge in GitHub), turning it off (`suspend: true`). ADR-0037 → ask whether it still holds, set `accepted`. Decision log: 0037. Playbook catalog: 07b done, repos `homelab-agents` + `homelab-gitops`, depends on 07. Close playbook 07 (its step 10 right-size is this playbook's first PR) and playbook 05's pending 7-day re-check (same PR): note it in both journals. Also carry playbook 07's 7-day watch here: 🧑 `kubectl -n monitoring get pods` restart counts for `alloy-operator` (10 restarts before 2026-11-13; still climbing means an open question), and any `SreCrewsDown` / `CrewsBudgetLow` firings in `#homelab-alerts` since 2026-11-13 (none expected): one line each in 07's journal. Remind the human to export the session and check it (`RUNNING.md`; new: `-----BEGIN RSA PRIVATE KEY-----`, `ghs_[A-Za-z0-9]{20}`). Open the handbook PR.

## When it's done
- Code: `homelab-agents` (`capacity_proposals`, `sre_crews.rightsize`, `merge_rightsize_pr` and tests); `homelab-gitops` (`platform/rightsize-targets.yaml` and its check, the CronJob, its Secret, NetworkPolicy and alert).
- Outside Git, written down: the GitHub App `homelab-rightsize` (permissions, installation), its key in the password manager, the `main` ruleset without bypass.
- Every Monday: one PR or none, linked in Hermes' report and merged with "merge it" + Allow once; a revert PR if last week's change hurt.
- Next: after eight weekly runs, decide whether decreases under a cap may auto-merge (a new ADR), and whether CPU joins.

## Video
Not recorded yet. Good candidate: step 8 ("my homelab right-sizes itself every Monday, and I approve it from my phone").
