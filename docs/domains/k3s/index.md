---
type: explanation
title: K3s
description: Overview of the k3s domain - what exists, how it fits, links to how-tos, runbooks and decisions.
domain: k3s
status: draft
visibility: public
reuse: lab-specific
created: 2026-10-20
updated: 2026-10-27
---

# K3s

Planned, not installed yet. [Playbook 03](https://github.com/ssaav5-ai-labs/handbook/blob/main/playbooks/03-k3s/PLAYBOOK.md) turns the two VMs from playbook 02 into a cluster: `k3s-01` on `pve01` is the server with embedded etcd, `k3s-02` on `pve02` is an agent ([ADR-0015](../../decisions/0015-k3s-embedded-etcd-server-and-agent.md)). Both have zram swap ([ADR-0016](../../decisions/0016-zram-swap-on-k3s-nodes.md)), and the kubeconfig sits on the laptop's Windows side, mounted into dev containers ([ADR-0017](../../decisions/0017-kubeconfig-on-windows-mounted-into-containers.md)). The install code lives in `homelab-infra/k3s/`.

When a third Proxmox node joins: [add a k3s server](howto-add-server.md).

The playbook run adds the reference page, runbooks and current state here.
