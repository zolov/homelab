packer {
  required_version = ">= 1.10.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.1"
    }
  }
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL, for example https://pve.example.local:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox API token user, for example root@pam!packer"
}

variable "proxmox_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name where the template is built"
}

variable "insecure_skip_tls_verify" {
  type    = bool
  default = true
}

variable "vm_id" {
  type    = number
  default = 9000
}

variable "vm_name" {
  type    = string
  default = "ubuntu-2404-cloudinit-docker"
}

variable "template_description" {
  type    = string
  default = "Ubuntu 24.04 LTS cloud-init template with QEMU guest agent, vim, curl, and Docker"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
}

variable "iso_storage_pool" {
  type    = string
  default = "local"
}

variable "storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "disk_size" {
  type    = string
  default = "10G"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password" {
  type      = string
  default   = "ubuntu"
  sensitive = true
}

source "proxmox-iso" "ubuntu_2404" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.insecure_skip_tls_verify
  node                     = var.proxmox_node

  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_name        = var.vm_name
  template_description = var.template_description

  boot_iso {
    type             = "ide"
    index            = 2
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  os              = "l26"
  qemu_agent      = true
  scsi_controller = "virtio-scsi-pci"

  cores  = var.cpu_cores
  memory = var.memory

  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    format       = "qcow2"
  }

  network_adapters {
    model  = "virtio"
    bridge = var.network_bridge
  }

  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  boot      = "order=scsi0;ide2"
  boot_wait = "5s"
  boot_command = [
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---",
    "<f10>"
  ]

  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "45m"
}

build {
  sources = ["source.proxmox-iso.ubuntu_2404"]

  provisioner "shell" {
    script = "scripts/install-docker.sh"
  }

  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }
}
