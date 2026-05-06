terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
  endpoint = "http://192.168.8.28:8006"
  username = "root@pam"
  password = "Ec49@skaiur"
  insecure = true
}

resource "proxmox_virtual_environment_vm" "debian" {
  count = 2

  name      = "docker-${count.index}"
  node_name = "proxmox"

  clone {
    vm_id = 8000
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "debian"
      password = "manjaro"
    }
  }
}
