---
type: howto
title: How to promote a Hermes-written skill
description: The loop for reviewing a skill Hermes staged in its pending queue, approving it, and turning it into a merged homelab-agents PR.
domain: ai-stack
status: draft
visibility: public
reuse: lab-specific
created: 2026-11-08
updated: 2026-11-08
related: [reference-hermes.md, index.md, ../../decisions/0009-hermes-for-local-automation.md, ../../decisions/0023-hermes-on-k3s-pod-as-sandbox.md]
---

# How to promote a Hermes-written skill

With `write_approval: true`, a skill Hermes writes or edits is not applied - it sits in a **pending queue** until approved. Reviewed skills reach Hermes only through `homelab-agents` (git-sync), so a skill takes effect as a merged PR, never as Hermes' own state.

## The loop

1. **Ask Hermes.** DM it: "Write a skill called `argocd-app-check` that ...". It stages the change.
2. **Review in Slack.** Hermes' slash commands need a **leading space**, or Slack swallows them as its own native slash commands:
   ```
    /skills pending        # list staged ids
    /skills diff <id>      # read one
    /skills approve <id>   # approve
   ```
   Approval validates the skill's frontmatter as YAML and **rolls back on error**.
3. **Copy it out (human).** Agents can't `kubectl exec` into Hermes, so a human copies the staged files out. The pending queue is JSON under `/opt/data/pending/skills/<id>.json`; read one with jq:
   ```bash
   kubectl -n hermes exec deploy/hermes -c hermes -- cat /opt/data/pending/skills/<id>.json | jq .
   ```
   Put the skill into `homelab-agents/hermes-skills/<name>/SKILL.md`.
4. **Open the PR.** Run `scripts/check-skills.sh` (it validates each SKILL.md's frontmatter as YAML), branch, commit, PR in `homelab-agents`.
5. **Merge.** git-sync picks it up within 5 minutes; delete Hermes' local copy so the Git version is the one it uses.

## Gotchas

- **Hermes stages edits on its own.** Its background review may patch an existing skill without being asked (it staged two `alert-triage` patches during playbook 06). When promoting, list the whole pending queue and discard anything you didn't ask for - an unasked patch can be typo-ridden or half-formed.
- **Leading space.** Every Hermes slash command in Slack starts with a space: ` /skills ...`, not `/skills ...`.
- **Approval validates YAML.** A skill with broken frontmatter (e.g. an unquoted `description` containing `: `) is refused at approval and rolled back; `check-skills.sh` catches the same thing in CI.
