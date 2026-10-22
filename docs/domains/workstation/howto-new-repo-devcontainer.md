---
type: howto
title: Create a new repo with the base devcontainer
description: Copy the base devcontainer template from the workstation repo into a new code repo and verify it starts with the handbook mount.
domain: workstation
tags: [devcontainer, devpod]
status: draft
created: 2026-10-22
updated: 2026-10-22
visibility: public
reuse: lab-specific
related: [../index.md]
---

# Create a new repo with the base devcontainer

The canonical devcontainer template (Dockerfile + devcontainer.json) lives in the **workstation repo** at `~/code/github.com/ssaav5-ai-labs/workstation/devcontainer/`.

## Prerequisites

- DevPod with Docker provider (`devpod provider add docker` if you haven't already)
- The workstation repo cloned at `~/code/github.com/ssaav5-ai-labs/workstation`

## Steps

1. Copy the base template into the new repo:

```powershell
cp $env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\devcontainer\Dockerfile <new-repo>\.devcontainer\
cp $env:USERPROFILE\code\github.com\ssaav5-ai-labs\workstation\devcontainer\devcontainer.json <new-repo>\.devcontainer\
```

2. Start the workspace:

```powershell
devpod up <new-repo> --ide vscode
```

## Verify

- `ls /knowledge/handbook/docs` shows the handbook inside the container.
- `opencode` starts and connects through the gateway.
- `kubectl version --client`, `helm version`, `tofu version`, `sops version`, `age --version`, `k9s version` all print.

## Undo / rollback

```powershell
devpod delete <workspace-name>
```

## Related decisions

- [ADR-0008: vendor-neutral AI stack](../../decisions/0008-vendor-neutral-ai-stack.md)
- [ADR-0006: local repo layout](../../decisions/0006-local-repo-layout.md)