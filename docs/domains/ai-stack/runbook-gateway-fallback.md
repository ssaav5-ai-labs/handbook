---
type: runbook
title: Fall back to the laptop gateway
description: When and how to switch containers from the cluster LiteLLM gateway to the laptop Compose gateway, and back.
domain: ai-stack
tags: [gateway, litellm, fallback, runbook]
status: draft
visibility: public
reuse: lab-specific
created: 2026-11-04
updated: 2026-11-04
related: [reference-gateway.md, index.md, ../../../playbooks/05-monitoring-gateway/PLAYBOOK.md]
---

# Fall back to the laptop gateway

The cluster gateway (`homelab-gitops/platform/llm-gateway/`, `http://llm.192.168.86.211.nip.io/v1`)
is primary. The laptop Compose gateway (`workstation/gateway/`) is the fallback.

## When to use it

- The cluster is down or a `k3s-*` node is unavailable.
- `http://llm.192.168.86.211.nip.io/v1` does not answer.
- nip.io is down (the hostname will not resolve).

## Check which gateway a container uses

```bash
echo $LLM_GATEWAY_URL
```

`http://host.docker.internal:4000` is the fallback; `http://llm.192.168.86.211.nip.io` is the cluster.

## Fall back (cluster down)

In PowerShell on the laptop:

```powershell
cd "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\gateway"
Copy-Item .env.example .env   # only if .env is missing; fill OPENROUTER_API_KEY and LITELLM_MASTER_KEY
docker compose up -d
setx LLM_GATEWAY_URL "http://host.docker.internal:4000"
```

Close PowerShell and open a new window (`setx` only affects new windows). Recreate the container:

```powershell
devpod up "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops" --recreate --ide none
```

In the new container:

```bash
echo $LLM_GATEWAY_URL          # http://host.docker.internal:4000
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $LLM_GATEWAY_KEY" \
  "$LLM_GATEWAY_URL/v1/models"  # 200
```

## Go back to the cluster

In PowerShell:

```powershell
setx LLM_GATEWAY_URL "http://llm.192.168.86.211.nip.io"
```

Close and reopen PowerShell, recreate the container, and verify again. Then stop the fallback:

```powershell
docker stop llm-gateway
```

`docker start llm-gateway` brings it back. Other containers (`handbook`, `homelab-infra`) pick up the
new URL on their next `devpod up ... --recreate`.

## Notes

- The fallback config is `workstation/gateway/config.yaml`; the primary is
  `homelab-gitops/platform/llm-gateway/config.yaml`. Keep `fast`/`code`/`reason` in sync. `local`
  (Ollama) exists only on the fallback.
- The fallback image is pinned (`v1.106.6`); update it deliberately.
- Requests fail with `401` if the master key in `.env` does not match `LLM_GATEWAY_KEY` in the
  container.
