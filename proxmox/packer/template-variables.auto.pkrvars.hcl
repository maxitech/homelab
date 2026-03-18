# Example Packer Variables File
# Copy this file to variables.auto.pkrvars.hcl and fill in your values
# This file must be placed on the same level as your Packer template (e.g., ubuntu-22.04.4-LTS.pkr.hcl)
# Note: Some variables are optional and have default values, but you can override them here as needed.

# Proxmox Connection
proxmox_api_url          = "https://proxmox.example.com:8006/api2/json"
proxmox_api_token_id     = "root@pam!packer"
proxmox_api_token_secret = "your-secret-token-here"
proxmox_node             = "pve"
vm_id                    = "9000"
image_name               = "ubuntu-2404-template"
vm_description           = "Ubuntu 24.04 Noble Numbat Template - Created via Packer"
disk_size                = "20G"
cpu_cores                = "2"
memory_mb                = "2048"
network_bridge           = "vmbr0"
cloudinit_storage        = "local-lvm"
boot_wait                = "10s"
http_bind_address        = "<IP_ADDRESS>"
http_port_min            = 8000
http_port_max            = 8050
ssh_username             = "ubuntu"
ssh_password             = "ubuntu"
ssh_timeout              = "30m"