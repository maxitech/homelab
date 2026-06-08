# Homelab

![Proxmox VE](https://img.shields.io/badge/Proxmox%20VE-E57000?style=flat-square&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logoColor=white)
![Packer](https://img.shields.io/badge/Packer-02A8EF?style=flat-square&logoColor=white)
![UniFi](https://img.shields.io/badge/UniFi-0559C9?style=flat-square&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell%20Script-4EAA25?style=flat-square&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)

Infrastructure-as-code, automation scripts, and operational runbooks for my self-hosted home lab — built around **Proxmox VE**, **Docker**, **Packer**, and a segmented **UniFi** network.

This repository documents _how_ the lab is organized and _why_, so that its layout, naming, and conventions stay consistent and reproducible over time.

## Table of Contents

- [Overview](#overview)
- [Network Architecture](#network-architecture)
  - [VLAN Segmentation](#vlan-segmentation)
  - [IP Addressing Scheme](#ip-addressing-scheme)
  - [Remote Access](#remote-access)
- [Compute Architecture](#compute-architecture)
  - [Proxmox VM/CT ID Ranges](#proxmox-vmct-id-ranges)
- [Repository Structure](#repository-structure)
- [Guides](#guides)
  - [Building VM Templates with Packer](#building-vm-templates-with-packer)
  - [VM Bootstrap & Hardening Scripts](#vm-bootstrap--hardening-scripts)
  - [Self-Hosted Services (Docker Compose)](#self-hosted-services-docker-compose)
  - [Proxmox Backup Server: Mounting NAS Storage](#proxmox-backup-server-mounting-nas-storage)
  - [Immich: Migrating Photo Storage to a NAS](#immich-migrating-photo-storage-to-a-nas)
  - [Renaming a Proxmox VE Node](#renaming-a-proxmox-ve-node)
- [License](#license)

## Overview

The lab runs on **Proxmox VE** and hosts everything from core infrastructure (DNS, reverse proxy) to general-purpose applications and disposable test environments. Everything that can reasonably be defined as code is: VM templates are built with **Packer** and **cloud-init**, fresh VMs are bootstrapped and hardened with a small set of idempotent shell scripts, and services are deployed with **Docker Compose**.

To keep the environment predictable as it grows, two conventions tie everything together:

- A fixed **ID range scheme** for Proxmox VMs/containers, so a resource's purpose is recognizable from its ID alone (see [Compute Architecture](#compute-architecture))
- A purpose-built **VLAN layout** in UniFi that segments traffic by trust level and function (see [Network Architecture](#network-architecture))

The sections below describe both, plus the contents of this repository and the operational runbooks it captures.

## Network Architecture

### VLAN Segmentation

All network segmentation is managed in UniFi. Each VLAN isolates traffic by trust level and function:

| VLAN ID | Name                | Purpose                                                                                                      |
| ------: | ------------------- | ------------------------------------------------------------------------------------------------------------ |
|       1 | `MANAGEMENT`        | UniFi infrastructure devices (access points, switches, gateway, etc.)                                        |
|      10 | `SERVER (PHYSICAL)` | Physical server hosts                                                                                        |
|      20 | `CRITICAL_SERVICES` | Core infrastructure services (e.g. DNS)                                                                      |
|      30 | `SERVICES (APPS)`   | General-purpose application services                                                                         |
|      40 | `STORAGE`           | Storage systems (NAS, backup targets)                                                                        |
|      50 | `DEVOPS`            | DevOps and automation tooling                                                                                |
|      60 | `VM_PLAYGROUND`     | Sandbox / experimental VMs                                                                                   |
|     100 | `TRUSTED`           | Trusted personal clients                                                                                     |
|     150 | `IOT`               | IoT devices                                                                                                  |
|     200 | `GUEST`             | Guest network                                                                                                |
|     250 | `UNTRUSTED`         | Default VLAN assigned to unused switch ports — isolates any device plugged in without explicit configuration |

### IP Addressing Scheme

Every VLAN is provisioned as its own `/24` (`255.255.255.0`) subnet, addressed using one consistent pattern:

```
10.<location>.<vlan_id>.<host>
```

| Octet      | Meaning                                                             |
| ---------- | ------------------------------------------------------------------- |
| `location` | Fixed identifier for the physical site                              |
| `vlan_id`  | The VLAN ID from the table above, used directly as the subnet octet |
| `host`     | Host/client identifier within that subnet                           |

For example, the `SERVICES (APPS)` VLAN (`30`) at a given site resolves to `10.<location>.30.0/24`. This keeps subnet membership self-describing — the VLAN a host belongs to can be read directly from its IP address.

### Remote Access

No service is reachable directly from personal devices — every connection follows the same bastion pattern:

1. **SSH key-based authentication only.** Password authentication is disabled on every VM (see [`11-disable-pwd-ssh-auth.sh`](proxmox/vm-core-scripts/vm-setup/11-disable-pwd-ssh-auth.sh)); access is by Ed25519 key pair.
2. **A single jump host (bastion)** sitting in the `MANAGEMENT` VLAN is the only host reachable directly. Every other VM is reached by `ProxyJump`-ing through it via SSH.
3. **Web UIs are reached through SSH local port forwarding**, rather than being exposed on the network. Each dashboard (Proxmox, AdGuard Home, Nginx Proxy Manager, ...) is tunneled to a local port on demand through the jump host.

A sanitized excerpt of the SSH client config that drives this (the real version, with actual hosts/IPs/usernames, intentionally lives outside this repository — see the note below):

```sshconfig
# The bastion — the only host reachable directly, sitting in the MANAGEMENT VLAN
Host jumphost
    HostName 10.<location>.50.<host>
    User <username>
    IdentityFile ~/.ssh/id_ed25519

# Any other VM is reached *through* the jump host...
Host proxmox-ui
    HostName 10.<location>.10.<host>
    User <username>
    ProxyJump jumphost
    LocalForward 8006 127.0.0.1:8006
    IdentityFile ~/.ssh/id_ed25519

# ...and a service's web UI is tunneled to a local port on demand
Host nginx-proxy-manager
    HostName 10.<location>.30.<host>
    User <username>
    ProxyJump jumphost
    LocalForward 8081 10.<location>.30.<host>:81
    IdentityFile ~/.ssh/id_ed25519
```

> **Note:** `~/.ssh/config` is not version-controlled in this repository — it encodes real internal hostnames, IP addresses, and usernames. It's kept in a private location instead.

## Compute Architecture

### Proxmox VM/CT ID Ranges

VM and container IDs on the Proxmox node are allocated from fixed ranges, so a resource's role is recognizable from its ID alone — no need to cross-reference a separate inventory:

| ID Range        | Category          | Description                                   |
| --------------- | ----------------- | --------------------------------------------- |
| `10000`–`19999` | Management        | Management VMs                                |
| `20000`–`29999` | Critical Services | Core infrastructure (e.g. DNS, reverse proxy) |
| `30000`–`39999` | Services / Apps   | General-purpose application workloads         |
| `40000`–`49999` | DevOps            | CI/CD and automation tooling                  |
| `80000`–`89999` | Test / Sandbox    | Disposable, experimental VMs                  |
| `90000`–`99999` | Templates         | Golden images (e.g. Packer-built templates)   |

Ranges not listed above are currently unallocated and reserved for future use.

## Repository Structure

```
homelab/
└── proxmox/
    ├── docker/                   Docker Compose stacks for self-hosted services
    │   ├── adguard/              AdGuard Home — network-wide DNS & ad-blocking
    │   └── nginx-proxy-manager/  Reverse proxy & TLS termination
    ├── packer/                   Packer templates for building Proxmox VM images
    │   └── ubuntu-server/        Ubuntu Server 24.04 cloud-init template
    └── vm-core-scripts/
        └── vm-setup/             Post-provisioning bootstrap & hardening scripts
```

## Guides

### Building VM Templates with Packer

[`proxmox/packer/ubuntu-server`](proxmox/packer/ubuntu-server) contains a Packer template that builds an Ubuntu Server 24.04 (Noble Numbat) cloud-init-ready VM template directly on Proxmox via the `proxmox-iso` builder.

**Usage:**

1. Copy [`template-variables.auto.pkrvars.hcl`](proxmox/packer/template-variables.auto.pkrvars.hcl) to `variables.auto.pkrvars.hcl`, placed alongside the `.pkr.hcl` file.
2. Fill in your Proxmox API connection details and desired VM specs. This file is git-ignored, so credentials never get committed.
3. Run `packer init` and `packer build` against [`ubuntu-22.04.4-LTS.pkr.hcl`](proxmox/packer/ubuntu-server/ubuntu-22.04.4-LTS.pkr.hcl).

The build:

- Boots the ISO and runs an unattended `autoinstall` via the [`http/user-data`](proxmox/packer/ubuntu-server/http/user-data) cloud-init configuration
- Strips machine-specific state (SSH host keys, machine ID, cloud-init artifacts) so the resulting template can be safely cloned
- Installs [`files/99-pve.cfg`](proxmox/packer/ubuntu-server/files/99-pve.cfg) to keep cloud-init's datasource list compatible with Proxmox

### VM Bootstrap & Hardening Scripts

[`proxmox/vm-core-scripts/vm-setup`](proxmox/vm-core-scripts/vm-setup) contains a small, ordered set of scripts that bring a freshly cloned VM into a known-good baseline state. [`run-all.sh`](proxmox/vm-core-scripts/vm-setup/run-all.sh) runs them in sequence:

| Script                                                                                      | Purpose                                                                                         |
| ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [`00-system-update.sh`](proxmox/vm-core-scripts/vm-setup/00-system-update.sh)               | Updates and upgrades all system packages                                                        |
| [`10-disable-default-user.sh`](proxmox/vm-core-scripts/vm-setup/10-disable-default-user.sh) | Locks and expires the default cloud-init user                                                   |
| [`11-disable-pwd-ssh-auth.sh`](proxmox/vm-core-scripts/vm-setup/11-disable-pwd-ssh-auth.sh) | Disables SSH password authentication (key-based auth only)                                      |
| [`20-install-docker.sh`](proxmox/vm-core-scripts/vm-setup/20-install-docker.sh)             | Installs Docker Engine and the Compose plugin, and adds the invoking user to the `docker` group |
| [`30-test-docker.sh`](proxmox/vm-core-scripts/vm-setup/30-test-docker.sh)                   | Verifies the installation by running the `hello-world` container                                |

Run it with:

```bash
bash run-all.sh
```

Docker installation (and the subsequent reboot) is prompted for interactively, so the same script works for both minimal VMs and Docker hosts.

### Self-Hosted Services (Docker Compose)

[`proxmox/docker`](proxmox/docker) holds the Compose definitions for services running on top of the VM baseline above.

| Service                 | Description                                                                | Compose File                                                                                             |
| ----------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **AdGuard Home**        | Network-wide DNS server with ad- and tracker-blocking                      | [`docker/adguard/docker-compose.yml`](proxmox/docker/adguard/docker-compose.yml)                         |
| **Nginx Proxy Manager** | Reverse proxy with a web UI for managing TLS certificates and host routing | [`docker/nginx-proxy-manager/docker-compose.yml`](proxmox/docker/nginx-proxy-manager/docker-compose.yml) |

### Proxmox Backup Server: Mounting NAS Storage

How to mount a network share as a backup datastore target for Proxmox Backup Server:

1. Install the CIFS client utilities:
   ```bash
   apt install cifs-utils
   ```
2. Create a mount point:
   ```bash
   mkdir /mnt/nas
   ```
3. Create a credentials file at `/etc/samba/.smbcreds`:
   ```
   username=<smb_username>
   password=<smb_password>
   ```
4. Restrict its permissions:
   ```bash
   chmod 400 /etc/samba/.smbcreds
   ```
5. Mount the share:
   ```bash
   mount -t cifs -o rw,vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34 //<nas_ip_address>/<share_name> /mnt/pbs-backups
   ```
6. Persist the mount in `/etc/fstab`:
   ```
   //<nas_ip_address>/<share_name> /mnt/test-pbs cifs vers=3.0,credentials=/etc/samba/.smbcreds,uid=34,gid=34,defaults 0 0
   ```

### Immich: Migrating Photo Storage to a NAS

How to move [Immich's](https://immich.app/) media storage off local disk and onto a NAS share — mounted on the Proxmox host and passed through to the LXC container running Immich.

**1. Mount the share on the Proxmox host (PVE):**

- Find the Immich system UID/GID inside the LXC: `grep immich /etc/passwd`
- Create the mount point: `mkdir /mnt/immich-nas`
- Add an entry to `/etc/fstab`:
  ```
  //<nas_ip_address>/immich /mnt/immich-nas cifs vers=3.0,credentials=/etc/samba/.smbcreds_immich,dir_mode=0777,file_mode=0777,uid=100999,gid=100991,defaults 0 0
  ```
  > The `uid`/`gid` values are the container's UID/GID shifted by the unprivileged-LXC offset (`100000 + <id>`), so the NAS share maps to the right owner inside the container.
- Apply and verify:
  ```bash
  mount -a
  systemctl daemon-reload
  ls -lF /mnt/immich-nas   # should list without errors
  mount | grep immich      # confirm the mount is active
  ```

**2. Pass the mount through to the LXC container:**

```bash
pct set <container_id> --mp0 /mnt/immich-nas,mp=/mnt/nas
```

Verify the mapping in `/etc/pve/lxc/<container_id>.conf` (look for `mp0: /mnt/immich-nas,mp=/mnt/nas`), then confirm the share is visible from inside the LXC shell: `ls -lF /mnt/nas`.

**3. Replicate the existing data structure onto the NAS:**

```bash
cp -ar /opt/immich/upload /mnt/nas
ls -lF /mnt/nas/upload
```

**4. Point Immich at the new location** by editing `/opt/immich/.env` — keep the original line as a commented reference:

```diff
- IMMICH_MEDIA_LOCATION=/opt/immich/upload
+ IMMICH_MEDIA_LOCATION=/mnt/nas/upload
```

**5. Re-link the `upload` directory in `/opt/immich/app`:**

```bash
cd /opt/immich/app
mv upload upload-original
ln -s /mnt/nas/upload upload
chown -R immich:immich upload
```

**6. Repeat the same re-link in `/opt/immich/app/machine-learning`:**

```bash
cd /opt/immich/app/machine-learning
mv upload upload-original
ln -s /mnt/nas/upload upload
chown -R immich:immich upload
```

### Renaming a Proxmox VE Node

1. Stop all VMs and containers on the node.
2. Connect via SSH and update the hostname references:

   ```bash
   nano /etc/hosts
   nano /etc/hostname
   nano /etc/postfix/main.cf

   hostnamectl set-hostname <new_node_name>
   systemctl restart pveproxy
   systemctl restart pvedaemon
   ```

3. Migrate the cluster filesystem entries to the new node name:

   ```bash
   cp -R /etc/pve/nodes/<old_node>/ /root/oldconfig
   mv /etc/pve/nodes/<old_node>/lxc/* /etc/pve/nodes/<new_node>/lxc
   mv /etc/pve/nodes/<old_node>/qemu-server/* /etc/pve/nodes/<new_node>/qemu-server

   rm -r /etc/pve/nodes/<old_node>
   reboot
   ```

4. Update storage references:
   ```bash
   nano /etc/pve/storage.cfg
   ```

## License

This repository is licensed under the [MIT License](LICENSE).
