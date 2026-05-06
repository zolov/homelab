# Packer Proxmox Ubuntu 24.04 Template

Creates an Ubuntu 24.04 LTS Proxmox VM template with:

- cloud-init
- QEMU guest agent
- vim
- curl
- Docker Engine and Docker Compose plugin

## Requirements

- Packer >= 1.10
- Proxmox API token with VM create/update permissions
- Ubuntu ISO storage available on the selected Proxmox node

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

The installer user is `ubuntu` with password `ubuntu`. Change `ssh_username`,
`ssh_password`, and the hashed password in `http/user-data` before building if
you do not want the default credentials baked into the installer.

