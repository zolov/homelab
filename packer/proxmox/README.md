# WIP
# Packer Ubuntu 24.04 Cloud Image

Builds a customized Ubuntu 24.04 LTS cloud image (`qcow2`) from the official
Ubuntu Noble cloud image.

The image includes:

- cloud-init
- QEMU guest agent
- vim
- curl
- Docker Engine and Docker Compose plugin

## Requirements

- Packer >= 1.10
- QEMU
- `qemu-img`
- Internet access for downloading the Ubuntu image and Docker packages

On Linux, use `qemu_accelerator = "kvm"` in your vars file.

## Usage

Create a local vars file:

```sh
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

Edit `variables.pkrvars.hcl`, then run:

```sh
packer init .
packer validate -var-file=variables.pkrvars.hcl .
packer build -var-file=variables.pkrvars.hcl .
```

The output image is written to `output/ubuntu-24.04-cloudimg/` by default.

The temporary build user is `ubuntu` with password `ubuntu`. Change
`ssh_username`, `ssh_password`, and `http/user-data` together if you need
different credentials during the Packer build.

## Import into Proxmox

Copy the generated `qcow2` to a Proxmox node and import it into a VM:

```sh
qm create 9000 --name ubuntu-2404-cloudimg --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 output/ubuntu-24.04-cloudimg/ubuntu-24.04-cloudimg-amd64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide0 local-lvm:cloudinit --boot order=scsi0 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1 --ipconfig0 ip=dhcp
qm template 9000
```
