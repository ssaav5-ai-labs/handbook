---
type: runbook
title: Start and stop the local dev environment
description: Daily routine on the Windows laptop - start the laptop gateway (fallback), start any repo's dev container, open a shell, resume the agent, check the cluster, and shut down.
domain: workstation
tags: [devpod, docker, windows, opencode, k3s, argocd, grafana, sops]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-11-04
related: [index.md, ../../../playbooks/00-workstation-knowledge/PLAYBOOK.md, ../ai-stack/runbook-gateway-fallback.md]
---

# Start and stop the local dev environment

Everything runs in **PowerShell on Windows** unless a step says "in the container".

## Start

1. Start **Docker Desktop** and wait until it says *Engine running*.
2. Start the laptop LLM gateway **only if the cluster gateway is down** (or you haven't switched to it yet — see [Gateway](#gateway)):
   ```powershell
   cd $env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\gateway
   docker compose up -d
   ```
3. Start the handbook dev container. The workspace already exists, so this only starts it (no rebuild):
   ```powershell
   devpod up handbook --ide none
   ```
4. Open a shell in it. `devpod ssh` fails on Windows ("The parameter is incorrect"), so use Docker. The container ID changes on every rebuild, so look it up each time:
   ```powershell
   $c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-handbook" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
   docker exec -it -u vscode -w /workspaces/handbook $c bash
   ```
   Need a second shell? Open another PowerShell window and run step 4 again.
5. In the container, resume the agent where you left off, or start fresh:
   ```bash
   opencode --continue    # last session
   opencode               # new session
   ```

## Any other repo container

For `homelab-gitops` (or any repo with a DevPod workspace), use the generic path:

```powershell
devpod up "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-gitops" --ide none
ssh homelab-gitops.devpod
cd /workspaces/homelab-gitops
```

Need a second shell (for `sops edit`)? Run `ssh homelab-gitops.devpod` in another PowerShell window. Both shells share the folder; don't create a branch in the human shell.

## Check it works

In the container:
```bash
echo "$LLM_GATEWAY_URL ${LLM_GATEWAY_KEY:+key set}"
curl -s -H "Authorization: Bearer $LLM_GATEWAY_KEY" "$LLM_GATEWAY_URL/v1/models" | grep -o '"id":"[^"]*"'
```
You should see the URL, `key set`, and the aliases fast, code, reason and local. OpenCode's footer should show `code · LLM gateway`.

## Check the cluster

In the `homelab-gitops` shell:

```bash
kubectl get nodes                 # both Ready
kubectl -n argocd get applications
```

In Grafana Cloud (`https://<stack>.grafana.net`) → **Alerting → Alert rules** → `homelab` folder: `LabSilent` is `Normal`. Argo CD apps are `Synced`/`Healthy`.

## Gateway

The cluster gateway (`http://llm.<k3s-01-ip>.nip.io`) is primary after playbook 05; the laptop Compose gateway is the fallback. Keep the laptop gateway running until `LLM_GATEWAY_URL` is switched, then start it only when the cluster is down. See [the fallback runbook](../ai-stack/runbook-gateway-fallback.md).

## Shortcut (optional)

Add this to your PowerShell profile (`notepad $PROFILE`), open a new window, and then `hb` (short for "handbook") does steps 1-4 in one go, starting Docker Desktop if it isn't running:
```powershell
function hb {
  docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    Write-Host "Waiting for Docker Desktop..."
    do { Start-Sleep 3; docker info *> $null } while ($LASTEXITCODE -ne 0)
  }
  docker compose -f "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\gateway\compose.yaml" up -d
  devpod up handbook --ide none
  $c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-handbook" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
  docker exec -it -u vscode -w /workspaces/handbook $c bash
}
```

## Stop

```powershell
devpod stop handbook
docker compose -f "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\gateway\compose.yaml" stop
```
OpenCode history survives stops and rebuilds (it lives in the `opencode-data` volume). Uncommitted files survive too, because the handbook folder is on Windows.

If you've switched to the cluster gateway, remove the `docker compose ... up -d` line from the `hb` shortcut; the laptop gateway is the fallback now.

## When something is off

| Symptom | Fix |
|---|---|
| `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine` | Docker Desktop isn't running (step 1). Start it, wait until `docker info` works, then retry. |
| `devpod` not recognized | The alias from playbook 00 isn't loaded: open a new PowerShell window, or check `$PROFILE`. |
| `$c` is empty | The container isn't running: rerun step 3 and check `docker ps`. |
| Env vars empty in the container | They come from Windows user variables at container creation. Check `echo $env:LLM_GATEWAY_URL` in PowerShell, then `devpod up handbook --recreate --ide none`. |
| Gateway calls fail | `docker compose ps` in `workstation\gateway`; `docker compose logs --tail 50`. |
| Changed `devcontainer.json` | `devpod up handbook --recreate --ide none` (history and files are kept). |
