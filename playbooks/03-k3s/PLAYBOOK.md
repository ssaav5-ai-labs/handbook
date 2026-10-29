---
type: playbook
title: Install a two-node k3s cluster with zram, ready to grow to three servers
description: Turns the two k3s VMs from playbook 02 into a verified k3s cluster (server with embedded etcd on k3s-01, agent on k3s-02), with zram swap, etcd snapshots and a kubeconfig on the workstation.
domain: k3s
tags: [k3s, kubernetes, etcd, zram, swap, kubeconfig, infrastructure-as-code]
status: draft
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: portable
repo: homelab-infra
depends_on: [../02-proxmox]
related:
  - ../../docs/decisions/0013-two-nodes-without-qdevice.md
  - ../../docs/decisions/0015-k3s-embedded-etcd-server-and-agent.md
  - ../../docs/decisions/0016-zram-swap-on-k3s-nodes.md
  - ../../docs/decisions/0017-kubeconfig-on-windows-mounted-into-containers.md
  - ../../docs/domains/k3s/howto-add-server.md
  - ../../docs/domains/proxmox/reference-hardware.md
  - ../../docs/open-questions/index.md
blog: candidate
---

# Install a two-node k3s cluster with zram, ready to grow to three servers

## What you'll have at the end
A k3s cluster on the two VMs from playbook 02: `k3s-01` (on `pve01`) is the server, running the control plane with embedded etcd, and `k3s-02` (on `pve02`) is an agent ([ADR-0015](../../docs/decisions/0015-k3s-embedded-etcd-server-and-agent.md)). Both VMs have compressed swap in RAM (zram) with a small disk swap file as a safety net ([ADR-0016](../../docs/decisions/0016-zram-swap-on-k3s-nodes.md)). etcd is snapshotted every night just before the Proxmox backup. `kubectl` works from the dev containers on the laptop, with the kubeconfig kept on Windows so it survives container rebuilds ([ADR-0017](../../docs/decisions/0017-kubeconfig-on-windows-mounted-into-containers.md)).

Everything is code in `homelab-infra/k3s/`: rebuilding a node is `tofu apply`, then two scripts. When a third Proxmox node joins, the cluster grows to three servers with [add a k3s server](../../docs/domains/k3s/howto-add-server.md). Argo CD is playbook 04, so this playbook installs no apps.

```
pve01                         pve02
└─ k3s-01  server + etcd      └─ k3s-02  agent
   4 vCPU, 4.5 GB, zram          4 vCPU, 4.5 GB, zram
        ▲   6443 (API)
        │
laptop: dev container ── kubectl (kubeconfig from %USERPROFILE%\.kube)
```

## Before you start 🧑
- [ ] Playbook 02 is done through step 8: both VMs answer `ssh -i $env:USERPROFILE\.ssh\homelab debian@<vm-ip> hostname` from PowerShell, and the nightly backup jobs exist.
- [ ] Docker Desktop is running, and only the `homelab-infra` dev container is up (8 GB laptop). Stop other containers only when no agent is working in them.
- [ ] A password manager entry is ready for the k3s cluster token (step 3 creates it). Without the token, etcd snapshots can't be restored.
- [ ] Create the kubeconfig folder on Windows and copy your SSH key into the container (PowerShell):
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.kube" | Out-Null
$r = "$env:USERPROFILE\code\github.com\ssaav5-ai-labs\homelab-infra"
devpod up $r --ide none
$c = docker ps --format "{{.ID}} {{.Image}}" | Select-String "vsc-homelab-infra" | ForEach-Object { $_.Line.Split(" ")[0] } | Select-Object -First 1
docker exec -u vscode $c mkdir -p /home/vscode/.ssh
docker cp "$env:USERPROFILE\.ssh\homelab" "${c}:/home/vscode/.ssh/homelab"
docker exec -u root $c chown vscode:vscode /home/vscode/.ssh/homelab
docker exec -u root $c chmod 600 /home/vscode/.ssh/homelab
docker exec -it -u vscode -w /workspaces/homelab-infra $c bash
```
If the container already has `~/.ssh/homelab` (a rebuilt container after step 9 keeps it in a volume), skip the `docker cp` lines.

## Kick it off
In the container's terminal, load the SSH key into an agent first, so the AI agent can use it without seeing it (you type the key's passphrase here, if it has one), then start OpenCode from the same shell:
```bash
eval "$(ssh-agent -s)"; ssh-add ~/.ssh/homelab
opencode
```
> Read `/knowledge/handbook/playbooks/RUNNING.md`, then run the playbook `/knowledge/handbook/playbooks/03-k3s`.

If you're resuming an earlier run, say so: the agent checks each step's Verify first and skips what's done.

## Steps

### 1. Check the VMs and the repo
**Why:** k3s goes onto what playbook 02 built, so first prove the VMs are what the code says and reachable from the container.
**Actions:** On a new handbook branch, open today's journal entry. If `qm agent <vmid> ping` on the VM's host fails, the VM has no QEMU guest agent (the playbook 02 run of 2026-10-29 built them before the template included it): `ssh debian@<ip> 'sudo apt-get update && sudo apt-get install -y qemu-guest-agent && sudo systemctl start qemu-guest-agent'` on each VM, so `tofu apply` stops waiting 15 minutes for it. In `homelab-infra`, add `tofu/outputs.tf` with an output `vm_ips`, a map of VM name to address taken from the `vms` variable (`{ for k, v in var.vms : k => v.ip }`), then run `tofu apply`, which changes no resources, so scripts read addresses from OpenTofu instead of a second copy. Create `k3s/nodes.conf`, committed, one line per node with its role; the first `server` line is the server that starts the cluster:
```
k3s-01 server
k3s-02 agent
```
**Verify:** `tofu -chdir=tofu plan` shows no changes. For each VM: `ssh debian@<ip> 'hostname; . /etc/os-release; echo $PRETTY_NAME; nproc; free -h; df -h /; timedatectl show -p NTPSynchronized'` shows Debian 13, 4 CPUs, about 4.4 GB, the disk size from `vms` (80 GB on `k3s-01`, 60 GB on `k3s-02`) and `NTPSynchronized=yes` (etcd needs synchronised clocks). `ssh debian@<k3s-01-ip> 'nc -zv <k3s-02-ip> 22'` succeeds (the VMs see each other across the two Proxmox hosts). `qm agent 101 ping` on `pve01` and `qm agent 102 ping` on `pve02` return without error.
**Record:** Journal: versions and free RAM on each VM before k3s.

### 2. Compressed swap in RAM (zram) and a safety-net swap file
**Why:** 4.5 GB is tight for Kubernetes. zram keeps rarely used memory compressed in RAM (typically 2 to 3 times smaller), which is far faster than disk and doesn't wear the SSD. A small swap file on disk, used only when zram is full, turns a sudden memory spike into slowness instead of an out-of-memory kill. This was promised on 2026-10-26 ([ADR-0016](../../docs/decisions/0016-zram-swap-on-k3s-nodes.md)).
**Questions:** zram size (default `ram / 2`, about 2.2 GB of compressed space) and algorithm (default `zstd`). Swap file size (default 1 GiB).
**Actions:** Write `k3s/prepare-node.sh`, idempotent, run on each VM with `ssh debian@<ip> 'sudo bash -s' < k3s/prepare-node.sh`:
- Check the kernel has zram: `modinfo zram`. The Debian `genericcloud` image runs the slim cloud kernel; if `zram` is missing, install `linux-image-amd64`, reboot, and record it.
- Install `systemd-zram-generator` and write `/etc/systemd/zram-generator.conf`:
```ini
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
```
- A 1 GiB `/swapfile` (`fallocate`, `chmod 600`, `mkswap`), in `/etc/fstab` with `pri=10`, so it's only used after zram.
- `/etc/sysctl.d/90-zram.conf` with the usual values for zram: `vm.swappiness = 180`, `vm.page-cluster = 0`, `vm.watermark_boost_factor = 0`, `vm.watermark_scale_factor = 125`.
- `systemctl daemon-reload`, start `systemd-zram-setup@zram0`, `swapon -a`, `sysctl --system`.

Reboot `k3s-02`, then `k3s-01` (nothing runs on them yet, so this is safe).
**Verify:** After the reboots, on each VM: `swapon --show` lists `/dev/zram0` with priority 100 and `/swapfile` with priority 10; `zramctl` shows `zstd`; `sysctl vm.swappiness` is 180. Running the script again changes nothing.
**Record:** ADR-0016 (ask whether it still holds and set it `accepted`), `docs/domains/k3s/reference-k3s.md` (memory section: zram, swap file, sysctls and why).

### 3. Pin k3s and write its configuration
**Why:** The cluster is defined by a pinned version and config files in Git, not by flags typed once. The cluster token protects joins and encrypts etcd's bootstrap data, so it lives outside Git, like the OpenTofu token.
**Questions:**
- The k3s version (default: the current `stable` channel at `https://update.k3s.io/v1-release/channels`, checked against `https://github.com/k3s-io/k3s/releases`). It must be within one minor version of the `kubectl` in the dev container (`kubectl version --client`).
- Keep k3s's bundled components: Traefik (ingress), ServiceLB (load balancer on node ports), local-path provisioner (storage on the node's disk) and metrics-server? Default **yes**, all four: they're small, and playbook 04 decides whether Argo CD takes any of them over.
- Pod and service networks: default `10.42.0.0/16` and `10.43.0.0/16`. Change them only if your LAN uses those ranges.
**Actions:**
- `k3s/versions.env`: `K3S_VERSION=<pinned, e.g. v1.xx.y+k3s1>`.
- The token, written by the agent without showing it: `grep -q '^K3S_TOKEN=' .env || printf 'K3S_TOKEN=%s\n' "$(openssl rand -hex 32)" >> .env`. 🧑 Then you copy it into your password manager from your own terminal (`grep K3S_TOKEN .env`), not through the agent.
- `k3s/config/server.yaml.tmpl`, rendered per node by the install script (`envsubst`):
```yaml
token: "${K3S_TOKEN}"
node-ip: "${NODE_IP}"
tls-san: ["${NODE_IP}"]
secrets-encryption: true
write-kubeconfig-mode: "0600"
etcd-snapshot-schedule-cron: "0 2 * * *"   # before the 03:00 Proxmox backup
etcd-snapshot-retention: 7
kubelet-arg:
  - "system-reserved=cpu=250m,memory=384Mi"
  - "kube-reserved=cpu=250m,memory=512Mi"
  - "eviction-hard=memory.available<256Mi"
```
  The install script adds `cluster-init: true` for the first server in `nodes.conf` and `server: https://<first-server-ip>:6443` for every other server. That's the hook for a third node: a new `server` line in `nodes.conf` joins etcd instead of starting a second cluster.
- `k3s/config/agent.yaml.tmpl`: `server: https://<first-server-ip>:6443`, `token`, `node-ip`, and the same `kubelet-arg` with `kube-reserved=cpu=100m,memory=256Mi` (an agent runs no control plane).
- `k3s/config/kubelet-swap.yaml`, a kubelet configuration drop-in that lets Burstable pods use swap (Kubernetes' `LimitedSwap`; without it, pods never swap and only the OS and k3s itself benefit from zram):
```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
memorySwap:
  swapBehavior: LimitedSwap
```
  Look up in the k3s docs for the pinned version where k3s reads kubelet drop-ins (recent versions use `/var/lib/rancher/k3s/agent/etc/kubelet.conf.d/`, or take `kubelet-arg: config-dir=<dir>`), and use that.
- `k3s/install.sh <node>`: looks up the node's role in `nodes.conf` and its address in `tofu output -json vm_ips`, renders the config, copies it to `/etc/rancher/k3s/config.yaml` (mode 600) and the drop-in to its directory, then runs the installer **from the pinned tag**, not from `get.k3s.io`: `curl -sfL https://raw.githubusercontent.com/k3s-io/k3s/$K3S_VERSION/install.sh | sudo INSTALL_K3S_VERSION=$K3S_VERSION INSTALL_K3S_EXEC=<server|agent> sh -`. The installer checks the binary's checksum. Running it again with the same version and config is a no-op restart; with a new `K3S_VERSION` it's an upgrade.

**Verify:** `shellcheck k3s/*.sh` is clean; `git check-ignore .env` prints `.env`; rendering the templates with a dummy token gives valid YAML (`yq` or `python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)'`); `git grep -nE '[0-9a-f]{64}'` finds no token.
**Record:** `reference-k3s.md` (version, config and why each setting), ADR-0015 (ask whether it still holds and set it `accepted`).

### 4. Install the server on k3s-01
**Why:** The first server starts the cluster and its etcd. Everything else joins it.
**Actions:** Show the command, then `k3s/install.sh k3s-01`.
**Verify:** On `k3s-01`: `sudo k3s check-config` reports no missing required items; `sudo k3s kubectl get nodes` shows `k3s-01 Ready control-plane,etcd` (role names as shown by the pinned version); `sudo k3s etcd-snapshot ls` runs without error (proves embedded etcd, not SQLite); `sudo k3s secrets-encrypt status` shows `Enabled`; `swapon --show` still lists zram; and the kubelet really allows swap: `sudo k3s kubectl get --raw /api/v1/nodes/k3s-01/proxy/configz | jq .kubeletconfig.memorySwap` shows `LimitedSwap`. If the pinned version ignores the drop-in, fix the path; if `LimitedSwap` can't be enabled, keep the default (`NoSwap`: zram still helps the OS and k3s), and record why.
**Record:** Journal: install time, memory used by k3s on `k3s-01` (`free -h` before and after).

### 5. Kubeconfig in the dev container
**Why:** `kubectl` and, from playbook 04, Argo CD's CLI run in the dev container, not on the VMs. The kubeconfig is a full cluster-admin credential, so it never goes into Git or a chat.
**Actions:** `k3s/kubeconfig.sh` fetches `/etc/rancher/k3s/k3s.yaml` from the first server over SSH (`sudo cat`), replaces `https://127.0.0.1:6443` with the server's address, renames the cluster, user and context from `default` to `homelab`, and writes `~/.kube/config` with mode 600 (merging with `KUBECONFIG=~/.kube/config:new kubectl config view --flatten` if the file already has other contexts). It never prints the file.
**Verify:** `kubectl config current-context` is `homelab`; `kubectl get nodes` shows `k3s-01 Ready`; `kubectl version` shows client and server within one minor version.
**Record:** Nothing yet (step 9 makes it survive rebuilds).

### 6. Join the agent on k3s-02
**Why:** The second node adds capacity on the other Proxmox host, so apps keep running while `pve01` reboots.
**Actions:** Show the command, then `k3s/install.sh k3s-02`.
**Verify:** `kubectl get nodes -o wide` shows both nodes `Ready`, with the internal IPs you chose and the pinned version; `kubectl get pods -A` shows everything `Running` or `Completed` (CoreDNS, Traefik, ServiceLB, local-path, metrics-server); `kubectl top nodes` returns numbers for both.
**Record:** Journal: memory used and free on each node (`kubectl top nodes`, `free -h`).

### 7. Smoke test
**Why:** `Ready` nodes don't prove that pods can talk across the two Proxmox hosts, that DNS works, or that storage binds. A short test does, and it's reusable after every upgrade.
**Actions:** Commit `k3s/smoke/` (namespace `smoke`, images pinned to tags looked up on their registries):
- A DaemonSet of a small HTTP echo server (for example `traefik/whoami`) with a Service, so one pod runs on each node.
- A one-off pod on each node (pinned with `nodeName`) that resolves `whoami.smoke.svc.cluster.local` and fetches it 10 times, plus the pod IP of the echo pod on the **other** node. Both nodes' pods must answer: that's the Flannel VXLAN overlay working between `pve01` and `pve02`.
- A 100 Mi PVC on `local-path` and a pod that writes and reads a file on it.
- `k3s/smoke/run.sh` applies it, waits, prints pass/fail per check and deletes the namespace.

**Verify:** `k3s/smoke/run.sh` passes every check; `kubectl get ns smoke` afterwards says not found.
**Record:** `reference-k3s.md` (how to run the smoke test).

### 8. Snapshots and node reboots 🧑
**Why:** The two failure modes that will happen first are a host reboot and a broken control plane. Both should be practiced now, while the cluster is empty.
**Actions:**
- `sudo k3s etcd-snapshot save --name manual-first` on `k3s-01`, then `sudo k3s etcd-snapshot ls`. Check the schedule: snapshots land at 02:00 in `/var/lib/rancher/k3s/server/db/snapshots/`, inside the VM disk that the 03:00 Proxmox job backs up to `backup-on-pve02`.
- **Agent reboot:** `kubectl drain k3s-02 --ignore-daemonsets --delete-emptydir-data`, then 🧑 reboot `k3s-02` (or `pve02`, one host at a time per [ADR-0013](../../docs/decisions/0013-two-nodes-without-qdevice.md)), then `kubectl uncordon k3s-02`.
- **Server reboot:** apply the echo DaemonSet from `k3s/smoke/` again, note the pods' restart counts, 🧑 reboot `k3s-01`. While it's down, `kubectl` fails (no control plane, accepted in ADR-0015) but the pod on `k3s-02` keeps running. When `k3s-01` is back, restart counts on `k3s-02` are unchanged. Clean up with `kubectl delete ns smoke`.

**Verify:** Both nodes `Ready` after each reboot, without manual fixes; zram active again after each boot (`swapon --show`).
**Record:** `docs/domains/k3s/runbook-node-maintenance.md` (drain, reboot one at a time, what to expect while `k3s-01` is down) and `docs/domains/k3s/runbook-etcd-restore.md` (restore a snapshot on `k3s-01` with `k3s server --cluster-reset --cluster-reset-restore-path=<snapshot>` and the original token, from the k3s docs for the pinned version; mark it **untested** unless you choose to practise it now, then rebuild with step 4).

### 9. Kubeconfig and SSH key that survive container rebuilds
**Why:** Today the kubeconfig and the SSH key live inside one container and are lost on rebuild, and the next repo (`homelab-gitops`, playbook 04) needs the same kubeconfig ([ADR-0017](../../docs/decisions/0017-kubeconfig-on-windows-mounted-into-containers.md)).
**Actions:**
- 🧑 Copy the kubeconfig to Windows, in the PowerShell window from *Before you start* (it still has `$c`): `docker cp "${c}:/home/vscode/.kube/config" "$env:USERPROFILE\.kube\config"`.
- In the `workstation` repo (clone it to `/tmp`, branch, PR) and in `homelab-infra/.devcontainer/devcontainer.json`, add two mounts and fix ownership in `postCreateCommand` like the existing `opencode-data` volume:
```json
"source=${localEnv:USERPROFILE}\\.kube,target=/home/vscode/.kube,type=bind",
"source=homelab-ssh,target=/home/vscode/.ssh,type=volume"
```
  and add `sudo chown vscode:vscode /home/vscode/.ssh && chmod 700 /home/vscode/.ssh &&` to the front of `postCreateCommand`. The SSH key goes in a Docker volume, not a Windows bind mount: Windows bind mounts show every file as world-readable and `ssh` refuses such keys.
- Update `docs/domains/workstation/index.md` (mounts and why) and `runbook-daily-start.md` if it lists container setup.

**Verify:** The `workstation` PR's checks pass and it's merged (🧑 approve). The rebuilt-container check happens after the session (see step 11).
**Record:** ADR-0017 (ask whether it still holds and set it `accepted`).

### 10. CI for the k3s code
**Why:** Scripts that rebuild the cluster get the same checks as the OpenTofu code.
**Actions:** In `homelab-infra/.github/workflows/ci.yml`, extend the `ci` job: `shellcheck` (pinned) over `k3s/**/*.sh`, and a YAML check of `k3s/config/` and `k3s/smoke/`. Open a PR with all of `k3s/`, the `vm_ips` output and the devcontainer change.
**Verify:** `ci` green on the PR; 🧑 you squash-merge it.

### 11. Finish
**Actions:** Close the journal entry (what broke, memory per node, zram compression ratio from `zramctl`, the reboot drill). Fill in `docs/domains/k3s/index.md` (what exists, diagram, links). In the open questions, close "k3s topology" with ADR-0015 and move "Secrets management" to playbook 04 (the cluster token sits in `.env` and the password manager for now). Update the playbook catalog (03 done, with the date). Remind the human to export the session and check it with `grep -cE 'sk-or-v1-[0-9a-f]{20}|sk-lf-[0-9a-f-]{20}|homelab-infra=[0-9a-f]{8}-|K3S_TOKEN=[0-9a-f]{16}|client-key-data: [A-Za-z0-9]|BEGIN OPENSSH'` (it matches real values only, not commands that mention them)` before sharing. Open the handbook PR.
**After the session 🧑:** exit OpenCode, then in PowerShell `devpod up $r --recreate --ide none`, copy the SSH key once more with the `docker cp` lines from *Before you start* (it now lands in the `homelab-ssh` volume and stays), and in the new container run `kubectl get nodes` (works without fetching anything) and `ssh -i ~/.ssh/homelab debian@<k3s-01-ip> hostname`. Run `gh auth login` again in the new container.

## When it's done
- Code: `homelab-infra/k3s/` (nodes, config templates, `prepare-node.sh`, `install.sh`, `kubeconfig.sh`, smoke test) and CI.
- Docs updated: `docs/domains/k3s/` (index, reference-k3s, runbook-node-maintenance, runbook-etcd-restore, howto-add-server), ADRs 0015 to 0017, workstation index, open questions, playbook catalog, journal.
- When a third Proxmox node joins: [add a k3s server](../../docs/domains/k3s/howto-add-server.md).
- Next playbook: 04 Argo CD (app-of-apps) in `homelab-gitops`.

## Video
Not recorded yet. Good candidates: step 2 ("zram on a 4.5 GB Kubernetes node") and step 8 ("what happens when the only k3s server reboots").
