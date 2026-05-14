# Ubuntu Server Noble (24.04.x)
# ---
# Packer Template to create an Ubuntu Server (Noble 24.04.x) on Proxmox

# Variable Definitions
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "vm_id" {
  type    = string
  default = ""
}

variable "image_name" {
  type    = string
  default = "ubuntu-srv-2404-template"
}

variable "vm_description" {
  type    = string
  default = "Ubuntu 24.04 Noble Numbat Template - Created via Packer"
}

variable "disk_size" {
  type    = string
  default = "20G"
}

variable "cpu_cores" {
  type    = string
  default = "2"
}

variable "memory_mb" {
  type    = string
  default = "2048"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "cloudinit_storage" {
  type    = string
  default = "local-lvm"
}

variable "boot_wait" {
  type    = string
  default = "10s"
}

variable "http_bind_address" {
  type    = string
  default = "0.0.0.0"
}

variable "http_port_min" {
  type    = number
  default = 8000
}

variable "http_port_max" {
  type    = number
  default = 8050
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "ubuntu"
}

variable "ssh_timeout" {
  type    = string
  default = "30m"
}

# variable "ssh_private_key_file" { type = string } # Placeholder for SSH Key Auth

packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}


# Resource Definition for the VM Template
source "proxmox-iso" "ubuntu-server" {

  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"

  # Skip TLS Verification
  insecure_skip_tls_verify = true

  # VM General Settings
  node                 = "${var.proxmox_node}"
  vm_id                = "${var.vm_id}"
  vm_name              = "${var.image_name}"
  template_description = "${var.vm_description}"

  # VM OS Settings
  # Local ISO File
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/ubuntu-24.04.4-live-server-amd64.iso"
    unmount      = true
    iso_checksum = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
  }

  # Download ISO
  # boot_iso {
  #     type             = "scsi"
  #     iso_url          = "${var.iso_url}"
  #     unmount          = true
  #     iso_storage_pool = "${var.iso_storage}"
  #     iso_checksum     = "${var.iso_checksum}"
  # }

  # VM System Settings
  qemu_agent = true

  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-single"


  disks {
    disk_size    = "${var.disk_size}"
    format       = "raw"
    storage_pool = "local-lvm"
    type         = "scsi"

  }

  # VM CPU Settings
  cores = "${var.cpu_cores}"

  # VM Memory Settings
  memory = "${var.memory_mb}"

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "${var.network_bridge}"
    firewall = false
  }

  # VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "${var.cloudinit_storage}"

  # PACKER Boot Commands
  boot         = "c"
  boot_wait    = "${var.boot_wait}"
  communicator = "ssh"
  boot_command = ["c", "linux /casper/vmlinuz -- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'", "<enter><wait><wait>", "initrd /casper/initrd", "<enter><wait><wait>", "boot<enter>"]

  # PACKER Autoinstall Settings
  http_directory    = "http"
  http_bind_address = "${var.http_bind_address}"
  http_port_min     = "${var.http_port_min}"
  http_port_max     = "${var.http_port_max}"

  ssh_username = "${var.ssh_username}"

  # SSH Password Authentication
  ssh_password = "${var.ssh_password}"

  # SSH Key Authentication
  # ssh_private_key_file = "${var.ssh_private_key_file}"

  # Raise the timeout, when installation takes longer
  ssh_timeout = "${var.ssh_timeout}"
  ssh_pty     = true
}

# Build Definition to create the VM Template
build {

  name    = "${var.image_name}"
  sources = ["source.proxmox-iso.ubuntu-server"]

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo systemctl enable ssh",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo sync"
    ]
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }

  # Add additional provisioning scripts here
  # ...
}