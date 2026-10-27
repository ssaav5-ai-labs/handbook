---
type: howto
title: Add a third Proxmox node
description: Check, install and join a new machine as pve03, with extra preparation for a Chromebox (MrChromebox UEFI firmware), then extend backups and k3s to it.
domain: proxmox
tags: [proxmox, cluster, quorum, chromebox, coreboot]
status: draft
created: 2026-10-27
updated: 2026-10-27
visibility: public
reuse: portable
related: [reference-hardware.md, ../../decisions/0013-two-nodes-without-qdevice.md]
blog: candidate
---

# Add a third Proxmox node

Not run yet: the third machine isn't chosen. When it is, this becomes a step of a playbook run and gets corrected against reality.

## Prerequisites
- The machine has wired Ethernet, VT-x/AMD-V, at least 16 GB RAM, and an SSD of 256 GB or more (or room to fit one).
- A fixed address and the hostname `pve03`.
- A USB stick with the Proxmox VE installer, the same major version as `pve01` (from `https://www.proxmox.com/en/downloads`, written with Rufus or balenaEtcher), a USB keyboard and a screen.

## Steps

### 1. Only for a Chromebox: replace the firmware
A Chromebox boots only ChromeOS until its firmware is replaced with MrChromebox's open-source UEFI build (coreboot + edk2). Look the exact model or board name up on MrChromebox's *Supported Devices* page first: it lists the firmware for that board and how its write protection is disabled. The flash wipes ChromeOS.
1. **Developer mode:** power off, hold the recovery button (pinhole, paperclip), power on, release. At the recovery screen press **Ctrl+D**, then confirm by pressing the recovery button again. It wipes the device and takes a few minutes.
2. **Firmware write protect off:** the method depends on the board (a screw or jumper on older models; on newer ones with a Cr50/Ti50 security chip, a jumper or closed-case debugging with a SuzyQ cable). Do exactly what the Supported Devices page says. Unplug power before opening the case.
3. **Flash:** boot ChromeOS, skip the login, open a shell with **Ctrl+Alt+F2** (log in as `chronos`), then `cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh`. Choose **Install/Update UEFI (Full ROM) Firmware**. When it offers, **back up the stock firmware to a USB stick** and keep it: it's the only way back to ChromeOS.
4. **Write protect back on (optional),** once Proxmox runs. Firmware updates then need it off again.

Check: the box shows a coreboot/UEFI boot screen and boots a USB stick from the boot menu (Esc).

### 2. Hardware checks
From the installer's shell (**Ctrl+Alt+F2**) or after installing:
- **Disk:** `lsblk -d -o NAME,SIZE,MODEL,TRAN`. Chromeboxes and thin clients often ship with 16-64 GB; fit a bigger SSD of the type the board takes (SATA or NVMe; 2242 or 2280).
- **RAM:** `free -h`; `dmidecode -t memory | grep -E 'Size|Maximum|Number Of Devices'` for slots and maximum. Open the case if the firmware says "To be filled by O.E.M." (see the 2026-10-26 journal).
- **Virtualisation:** `grep -cE 'vmx|svm' /proc/cpuinfo` is more than 0.
- **Ethernet:** `lspci -nnk | grep -iA3 ethernet` names the NIC and driver (often Realtek `r8169`, sometimes Intel `e1000e`). Proxmox doesn't bridge Wi-Fi.

### 3. Install and update
Hostname `pve03.<your-domain>`, the fixed address, gateway and DNS, the same storage layout as the other nodes. Then playbook 02, step 2 (no-subscription repo, upgrade, reboot) so it runs the same version.

### 4. Network and power checks
- `ethtool <nic>`: `Speed: 1000Mb/s`, `Duplex: Full`.
- `iperf3 -s` on `pve01`, `iperf3 -c <pve01-ip> -t 30` on `pve03`: about 900 Mbit/s or more.
- `journalctl -k | grep -iE 'r8169|e1000e|link (is )?down'`: no link flaps under load. For a flaky Realtek NIC, look up the current fix for that chip before changing drivers.
- Pull the power cable and plug it back in: the box must power on by itself.

### 5. Join
`pve03` must have no VMs. On `pve03`: `pvecm add <pve01-ip>` (root password of `pve01`, accept its fingerprint). Don't add a QDevice: with three nodes Proxmox advises against one.

### 6. Extend the rest
Re-run playbook 02: steps 4 to 8 pick up the new node (template `9003`, `k3s-03` in the OpenTofu map, its backups on `backup-on-pve01`). Then k3s grows to three servers: `k3s-03` joins as a server and `k3s-02` is rebuilt as one (etcd needs an odd number of members).

## Verify
`pvecm status` on any node: `Nodes: 3`, `Expected votes: 3`, `Quorate: Yes`. Three green nodes in the web UI. Then the drill from playbook 02, step 3 should stay `Quorate: Yes` without `pvecm expected 1`.

## Undo / rollback
Before any VMs live on it: on another node, `pvecm delnode pve03` with `pve03` powered off, then reinstall it before it ever reconnects. A Chromebox goes back to ChromeOS by flashing the saved stock firmware with the same script.

## Related decisions
[ADR-0013](../../decisions/0013-two-nodes-without-qdevice.md): two nodes without a QDevice until this happens.
