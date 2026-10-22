# Instructions for AI agents

This repo is the knowledge base for all of Shawn's lab work. Read `docs/meta/knowledge-system.md` before writing anything.

## Playbooks
When asked to run a playbook, follow `playbooks/RUNNING.md`. When writing a new one, copy `templates/playbook.md`.

## Before acting in any repo
- Read the relevant `docs/domains/<domain>/` pages and accepted ADRs in `docs/decisions/`.
- Check `docs/open-questions/` so you don't assume an undecided choice.

## When writing
- Every file needs the frontmatter from `docs/meta/knowledge-system.md`. Copy from `templates/`.
- One concept per file. Kebab-case file names. Don't move or rename files without being asked; paths are links.
- Journal: `docs/journal/YYYY/YYYY-MM-DD-<slug>.md`. Append, never rewrite past entries.
- ADRs: next free number, `docs/decisions/NNNN-<slug>.md`, `status: proposed` until Shawn accepts it. Never edit an accepted ADR except to set `status: superseded` and `superseded_by`.
- Prefer updating an existing how-to/runbook over creating a near-duplicate.

## Models and harnesses
- Call models only through the LLM gateway (`$LLM_GATEWAY_URL`) using aliases `fast`, `code`, `reason`, `local`. Never hard-code a vendor model ID or API in a repo; see ADR-0008.
- Keep instructions in `AGENTS.md` and skills in `.agents/skills/`; don't write harness-specific files except generated copies.

## Never
- Commit secrets, tokens, real public IPs, real hostnames, or employer/client material. Use placeholders like `<lab-domain>`.
- Mark anything `visibility: private` here; private content belongs in the personal career-vault repo.
- Push to `main`. Open a PR.
