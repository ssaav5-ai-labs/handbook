---
type: runbook
title: Start and stop the local dev environment
description: Daily routine - open any repo's dev container on the devbox VM with hbx (inside tmux), resume the agent, check the cluster; the laptop containers (hbl) are the fallback when pve03 is down.
domain: workstation
tags: [devpod, docker, windows, opencode, k3s, argocd, grafana, sops, devbox, tmux]
status: active
visibility: public
reuse: lab-specific
created: 2026-10-23
updated: 2026-11-20
related: [index.md, ../../../playbooks/00-workstation-knowledge/PLAYBOOK.md, ../../../playbooks/02c-devbox/PLAYBOOK.md, ../../decisions/0033-dev-containers-on-a-devbox-vm.md, ../ai-stack/runbook-gateway-fallback.md]
---

# Start and stop the local dev environment

Since playbook 02c (2026-11-20) the dev containers run on the `devbox` VM on `pve03` ([ADR-0033](../../decisions/0033-dev-containers-on-a-devbox-vm.md)). The laptop only runs PowerShell, `ssh` and editors; Docker Desktop doesn't need to be running. Everything here runs in **PowerShell on Windows** unless a step says "in the container".

## Start

```powershell
hb                     # the handbook
hbx homelab-gitops     # any other repo: handbook, homelab-infra, homelab-gitops, workstation
```

You land in `/workspaces/<repo>-box`, inside the tmux session `main`. All four containers can run at once, so open one PowerShell window per repo. In the container, resume the agent or start fresh:

```bash
opencode --continue    # last session
opencode               # new session
```

Closing the window, a dropped Wi-Fi or a sleeping laptop doesn't stop anything: run `hbx <repo>` again and you're back in the same tmux session, with OpenCode where you left it.

## The shortcuts

In your PowerShell profile (`notepad $PROFILE`; run `New-Item -Force $PROFILE` first if it doesn't exist), then `. $PROFILE` or a new window:

```powershell
Set-Alias devpod "$env:LOCALAPPDATA\DevPod\devpod-cli.exe"

function hbx([string]$repo = 'handbook') {
  $c = ssh devbox docker ps -q --filter "volume=/workspaces/$repo-box"
  if (-not $c) { devpod up "$repo-box" --ide none; $c = ssh devbox docker ps -q --filter "volume=/workspaces/$repo-box" }
  ssh -t devbox docker exec -it -u vscode -w "/workspaces/$repo-box" $c tmux new -A -s main
}

function hb { hbx handbook }
```

`hbx` asks Docker on the devbox for the container that mounts `/workspaces/<repo>-box`, starts the workspace with `devpod up` if none is running (after a devbox reboot), and attaches to tmux. It uses `docker exec` because `ssh <repo>-box.devpod` times out on Windows with DevPod's SSH provider. It relies on this entry in `$env:USERPROFILE\.ssh\config`:

```
Host devbox
  HostName 192.168.86.214
  User debian
  IdentityFile ~/.ssh/homelab
```

## Second shell

For `sops edit` or anything a human types while the agent works: inside tmux, `Ctrl+b c` opens a second window (`Ctrl+b n` switches). Don't create a branch in the human shell; both share the folder.

## Check it works

In the container:
```bash
echo "$LLM_GATEWAY_URL ${LLM_GATEWAY_KEY:+key set} ${GH_TOKEN:+gh set}"
curl -s -H "Authorization: Bearer $LLM_GATEWAY_KEY" "$LLM_GATEWAY_URL/v1/models" | grep -o '"id":"[^"]*"'
```
You should see the URL, `key set gh set`, and the aliases fast, code, reason and local. OpenCode's footer should show `code`.

## Check the cluster

In any container:

```bash
kubectl get nodes                 # three Ready
kubectl -n argocd get applications
```

In Grafana Cloud (`https://<stack>.grafana.net`) → **Alerting → Alert rules** → `homelab` folder: `LabSilent` is `Normal`. Argo CD apps are `Synced`/`Healthy`.

## Handbook on Windows

Obsidian and OpenKnowledge edit the Windows clone, which is no longer what the containers mount (they mount the devbox clone). `git pull` in `%USERPROFILE%\code\github.com\ssaav5-ai-labs\handbook` before editing there, and push through a PR as usual.

## Stop

Nothing to do. The containers keep running on the devbox. Optionally `devpod stop <repo>-box` to free memory on the devbox.

## Fallback: pve03 or the devbox is down

Start Docker Desktop and use the laptop workspaces as before, one at a time (the laptop has 8 GB). Add this to the profile too:

```powershell
function hbl([string]$repo = 'handbook') {
  docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    Write-Host "Waiting for Docker Desktop..."
    do { Start-Sleep 3; docker info *> $null } while ($LASTEXITCODE -ne 0)
  }
  devpod up $repo --ide none
  $c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-$repo" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
  docker exec -it -u vscode -w "/workspaces/$repo" $c bash
}
```

`hbl homelab-infra` starts Docker Desktop if needed and opens the laptop container. Stop it with `devpod stop <repo>` before opening another. The laptop LLM gateway (Compose in `workstation/gateway`) is only for when the cluster gateway is down; see [the fallback runbook](../ai-stack/runbook-gateway-fallback.md).

## When something is off

| Symptom | Fix |
|---|---|
| `hbx` hangs or `ssh devbox` fails | Is the VM up? Proxmox UI → `pve03` → VM 110. `ssh devbox hostname` should print `devbox`. |
| `hbx` prints `chdir to cwd ... no such file or directory` | The workspace ID is `<repo>-box`, so the folder is `/workspaces/<repo>-box`. Check `ssh devbox docker ps`. |
| `ssh <repo>-box.devpod` waits for "devpod agent to come up" and times out | Known on Windows with the SSH provider. Use `hbx`. |
| `Host key verification failed` from inside a container | The devbox's shared `known_hosts` is missing a host: `ssh-keyscan -t ed25519 <ip> >> ~/.ssh/known_hosts` in any container. |
| Env vars empty in a devbox container | They come from `~/.devbox/env` on the devbox at container creation (`ssh devbox 'cut -d= -f1 ~/.devbox/env'` lists the names). Fix the file, then `devpod up <repo>-box --recreate --ide none`. |
| Changed `.devcontainer/devbox/devcontainer.json` | Merge it, then `devpod up <repo>-box --recreate --ide none` (history in the `opencode-data` volume and the repo folder are kept). |
| `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine` | Only matters for `hbl`: Docker Desktop isn't running. `hbl` starts it. |
| OpenCode's logo shows only "code", or colours look washed out | tmux isn't passing true colour. In the container: `printf 'set -g default-terminal "tmux-256color"\nset -as terminal-features ",*:RGB"\n' > ~/.tmux.conf && tmux source-file ~/.tmux.conf`, then restart OpenCode. |
| A command with `"` inside fails in PowerShell (`template parsing error`, `accepts no arguments`) | PowerShell mangles inner double quotes when calling `ssh`/`docker`. Use single quotes outside, or none inside. |
