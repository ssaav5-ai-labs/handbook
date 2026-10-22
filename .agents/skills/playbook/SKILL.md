---
name: playbook
description: Run one of this repo's AI-first setup playbooks step by step with the user. Use when the user says "run the playbook ..." or names a folder under playbooks/.
---

Follow `playbooks/RUNNING.md` exactly for the playbook the user named. If they didn't name one, list `playbooks/*/PLAYBOOK.md` with each title and `depends_on`, and ask which to run.
