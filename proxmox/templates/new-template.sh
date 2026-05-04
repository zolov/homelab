#!/usr/bin/env bash

set -e

# === CONFIG ===
VM_ID=5000
VM_NAME="ubuntu-24.04-template"
STORAGE="local-lvm"
IMG_DIR="/var/lib/vz/template/iso"
IMG_NAME="ubuntu-24.04-server-cloudimg-amd64.img"
IMG_PATH="${IMG_DIR}/${IMG_NAME}"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
MEMORY=2048
CORES=2
DISK_SIZE="10G"
BRIDGE="vmbr0"

# === DOWNLOAD IMAGE ===
echo "===> Downloading ${IMG_NAME} image to ${IMG_DIR}"
mkdir -p ${IMG_DIR}

if [ ! -f "${IMG_PATH}" ]; then
  wget -O ${IMG_PATH} ${IMG_URL}
else
  echo "Image already exists, skipping download"
fi

# === CREATE VM ===
echo "===> Creating VM ${VM_ID}"

qm create ${VM_ID} \
  --name ${VM_NAME} \
  --memory ${MEMORY} \
  --cores ${CORES} \
  --net0 virtio,bridge=${BRIDGE}

# === IMPORT DISK ===
echo "===> Importing disk"
qm importdisk ${VM_ID} ${IMG_PATH} ${STORAGE}

# === ATTACH DISK ===
echo "===> Attaching disk"
qm set ${VM_ID} \
  --scsihw virtio-scsi-pci \
  --scsi0 ${STORAGE}:vm-${VM_ID}-disk-0

# === ADD CLOUD INIT DISK ===
echo "===> Adding cloud-init"
qm set ${VM_ID} --ide2 ${STORAGE}:cloudinit

# === BOOT CONFIG ===
qm set ${VM_ID} --boot c --bootdisk scsi0

# === SERIAL + CONSOLE (важно для cloud image) ===
qm set ${VM_ID} --serial0 socket --vga serial0

# === ENABLE QEMU GUEST AGENT ===
echo "===> Enabling QEMU Guest Agent"
qm set ${VM_ID} --agent enabled=1

# === RESIZE DISK ===
echo "===> Resizing disk to ${DISK_SIZE}"
qm resize ${VM_ID} scsi0 ${DISK_SIZE}

# === CLOUD INIT DEFAULTS ===
qm set ${VM_ID} \
  --ciuser ubuntu \
  --cipassword ubuntu \
  --sshkeys ~/.ssh/homelab.pub \
  --sshkeys ~/.ssh/id_rsa.pub \
  --ipconfig0 ip=dhcp

# === OPTIONAL: PREINSTALL QEMU AGENT VIA CLOUD INIT ===
# cat <<EOF > /var/lib/vz/snippets/${VM_ID}-cloudinit.yaml
# #cloud-config
# package_update: true
# packages:
#   - qemu-guest-agent
# runcmd:
#   - systemctl enable qemu-guest-agent
#   - systemctl start qemu-guest-agent
# EOF

qm set ${VM_ID} --cicustom "user=local:snippets/${VM_ID}-cloudinit.yaml"

# === CONVERT TO TEMPLATE ===
echo "===> Converting VM to template"
qm template ${VM_ID}

echo "===> DONE: Template ${VM_NAME} (${VM_ID}) is ready"
