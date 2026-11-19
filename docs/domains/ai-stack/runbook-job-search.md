---
type: runbook
title: Job-search runbook
description: Diagnose and fix the job-search MCP server, drafting crew and daily feed when something breaks.
domain: ai-stack
tags: [job-search, crewai, mcp, hermes, slack, career-vault, runbook]
status: draft
visibility: public
reuse: lab-specific
created: 2026-11-19
updated: 2026-11-19
related: [index.md, reference-job-search.md, reference-gateway.md, runbook-hermes.md]
---

# Job-search runbook

## Pod down or not ready

**Symptoms:** Hermes says the job-search tool is unavailable, or the pod is `CrashLoopBackOff`.

**Check order:**

1. **Pod status:**
   ```
   kubectl -n career get pods -l app=job-search -o wide
   ```
   Both containers (`server`, `git-sync`) must be `Ready`.

2. **Server logs:**
   ```
   kubectl -n career logs deploy/job-search -c server --since=10m
   ```
   Look for `outcome=error`, OOM kills, or Python tracebacks.

3. **Git-sync logs:**
   ```
   kubectl -n career logs deploy/job-search -c git-sync --tail=20
   ```
   Confirm the vault clone succeeded. `Permission denied (publickey)` means the read-only deploy key in `job-search` Secret needs rotation (see below).

4. **Hermes' MCP connection:**
   ```
   kubectl -n hermes exec deploy/hermes -c hermes -- hermes mcp list
   ```
   Confirm `jobs` shows as connected. If not, restart the Hermes pod.

5. **Restart the pod:**
   ```
   kubectl -n career rollout restart deploy/job-search
   ```

## Git push conflict (vault writes)

**Symptoms:** A draft or triage digest fails to write, and the server logs show `push conflict, retrying` or `RuntimeError: git push`.

The `_write_vault()` function handles one conflict automatically (pull, rebase, retry). If both attempts fail, someone else pushed to the vault between the pull and push.

**Fix:** Re-run the operation (Hermes `draft` again, or trigger the CronJob manually). The fresh run pulls the latest vault before committing. If it persists, check that no other client (Obsidian, another container) is pushing to `ssaav5/career-vault` at the same time.

## IMAP app password revoked or expired

**Symptoms:** Triage CronJob logs show `IMAP login failed` or `AUTHENTICATIONFAILED`.

**Fix:** The app password lives in the `job-triage` Secret (`IMAP_APP_PASSWORD`).
- Google invalidates app passwords if the account password changes or 2FA is turned off.
- Create a new app password in Gmail → Manage your Google Account → Security → 2-Step Verification → App passwords.
- 🧑 Edit with `sops edit platform/job-search/triage-secret.enc.yaml`, replace `IMAP_APP_PASSWORD` with the new password.
- The next CronJob run picks it up automatically. Validate with:
  ```
  kubectl -n career create job --from=cronjob/job-triage triage-test --dry-run=client -o yaml | kubectl apply -f -
  ```

## Budget reached

**Symptoms:** `score_role` returns "budget reached" or "insufficient quota" in Slack.

The `jobs` gateway key has a `3 USD / 30 days` budget.

1. **Check current spend:**
   - Port-forward the gateway and hit `/global/spend/logs?api_key=sk-jobs*` or check Langfuse (cost metadata only, no prompt text).
2. **Short-term:** Raise the key's budget to 5 USD (🧑 via port-forward), then lower it back after the batch.
3. **Long-term:** If this happens often, the `fast` scoring model is using too many tokens. Check Langfuse for token-per-call trends and adjust `max_tokens` in `score.py` or tune `profile.md`'s `shortlist_threshold` upward to score fewer roles.
4. **Fallback drill (playbook 10 drill 5):** Lower the key to 0.01 USD for an hour, call `score_role`, expect the "budget reached" message in Slack, then restore.

## Turn it off

1. **Remove from Hermes' managed config:**
   In `platform/hermes/managed/config.yaml`, remove the `jobs` MCP server block (or comment it out with `#`). PR, merge, Argo sync. Hermes restarts and the `job-search` skill won't offer its tools.
2. **Suspend the CronJob:**
   ```
   kubectl -n career patch cronjob job-triage -p '{"spec":{"suspend":true}}'
   ```
3. **Scale the pod to 0:**
   ```
   kubectl -n career scale deploy/job-search --replicas=0
   ```
   The vault writes stop, no scoring runs, no IMAP reads. The career-vault stays intact.

To turn it back on, undo each step in reverse: scale to 1, unsuspend the CronJob, restore the `jobs` MCP server in Hermes' config.

## Rotate credentials

### Deploy keys (vault read/write)

Two deploy keys on `ssaav5/career-vault`: `jobs-ro` (read-only, git-sync) and `jobs-rw` (write, `VAULT_WRITE_KEY`).

1. Generate new keys:
   ```
   ssh-keygen -t ed25519 -N '' -f /tmp/jobs-ro-new -C job-search-ro
   ssh-keygen -t ed25519 -N '' -f /tmp/jobs-rw-new -C job-search-rw
   ```
2. 🧑 In `ssaav5/career-vault` Settings → Deploy keys, add the **public keys** (`jobs-ro-new.pub` read-only, `jobs-rw-new.pub` with write access). Remove the old keys.
3. 🧑 Update `platform/job-search/secret.enc.yaml` with `sops edit`: paste the new **private** key contents into `VAULT_RO_KEY` and `VAULT_RW_KEY`.
4. PR, merge, Argo sync. Restart the pod:
   ```
   kubectl -n career rollout restart deploy/job-search
   ```

### MCP token (`JOBS_MCP_TOKEN`)

1. Generate:
   ```
   openssl rand -hex 32
   ```
2. 🧑 `sops edit platform/job-search/secret.enc.yaml`: replace `JOBS_MCP_TOKEN`.
3. 🧑 `sops edit platform/hermes/secret.enc.yaml`: update `JOBS_MCP_TOKEN` there too (Hermes needs it to connect).
4. PR both changes if they're in different repos. Merge, Argo sync. Restart both Hermes and job-search.

### Gateway key (`JOBS_GATEWAY_KEY`)

1. 🧑 Port-forward the gateway, delete the old `jobs` key, create a new one with the same spec (see `reference-gateway.md`).
2. 🧑 `sops edit platform/job-search/secret.enc.yaml`: replace `JOBS_GATEWAY_KEY`.
3. Merge, Argo sync, restart job-search.

### IMAP app password

See "IMAP app password revoked or expired" above. Only the `triage-secret.enc.yaml` needs updating (the CronJob's `job-triage` Secret, not the `job-search` Secret).