packer {
  required_version = ">= 1.10.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

variable "cloud_image_url" {
  type        = string
  description = "Ubuntu cloud image URL used as the base disk."
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "cloud_image_checksum" {
  type        = string
  description = "Checksum for the Ubuntu cloud image. The default points at Ubuntu's current SHA256SUMS file."
  default     = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
}

variable "output_directory" {
  type    = string
  default = "output/ubuntu-24.04-cloudimg"
}

variable "vm_name" {
  type    = string
  default = "ubuntu-24.04-cloudimg-amd64.qcow2"
}

variable "disk_size_mb" {
  type        = number
  description = "Final image size in MiB."
  default     = 10240
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory" {
  type        = number
  description = "Guest memory in MiB."
  default     = 2048
}

variable "qemu_binary" {
  type    = string
  default = "qemu-system-x86_64"
}

variable "qemu_accelerator" {
  type        = string
  description = "Use hvf on macOS, kvm on Linux, or none when hardware acceleration is unavailable."
  default     = "hvf"
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

source "qemu" "ubuntu_2404_cloudimg" {
  iso_url      = var.cloud_image_url
  iso_checksum = var.cloud_image_checksum
  disk_image   = true

  output_directory = var.output_directory
  vm_name          = var.vm_name
  format           = "qcow2"
  disk_size        = var.disk_size_mb
  disk_interface   = "virtio"

  headless    = true
  accelerator = var.qemu_accelerator
  qemu_binary = var.qemu_binary
  cpus        = var.cpu_cores
  memory      = var.memory

  cd_files = [
    "http/meta-data",
    "http/user-data",
  ]
  cd_label = "cidata"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "20m"

  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.qemu.ubuntu_2404_cloudimg"]

  provisioner "shell" {
    inline = ["sudo cloud-init status --wait"]
  }

  provisioner "shell" {
    script = "scripts/install-docker.sh"
  }

  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }

  post-processor "manifest" {
    output     = "${var.output_directory}/manifest.json"
    strip_path = true
  }
}
