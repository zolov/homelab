#!/usr/bin/env bash

set -Eeuo pipefail

########################################
# LOAD ENV
########################################

ENV_FILE="$(dirname "$0")/.env"

if [[ -f "${ENV_FILE}" ]]; then
  echo "===> Loading ${ENV_FILE}"

  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

########################################
# CONFIG
########################################

: "${VM_ID:=9000}"

: "${VM_NAME:=ubuntu-24.04-cloudinit-template}"

: "${IMG_DIR:=/var/lib/vz/template/cache}"
: "${WORK_IMG_NAME:=${IMG_NAME:-ubuntu-24.04-base.img}}"

: "${IMG_PATH:=${IMG_DIR}/${WORK_IMG_NAME}}"

: "${STORAGE:=local-lvm}"

: "${MEMORY:=2048}"
: "${BALLOON:=1024}"

: "${CORES:=2}"
: "${SOCKETS:=1}"

: "${CPU_TYPE:=host}"

: "${DISK_SIZE:=20G}"

: "${BRIDGE:=vmbr0}"

: "${CI_USER:=ubuntu}"

: "${SSH_KEY_PATH:=/tmp/ssh_public_key}"

########################################
# HELPERS
########################################

if [[ -n "${TEMPLATE_SSH_PUBLIC_KEY:-}" ]]; then
  printf '%s\n' "${TEMPLATE_SSH_PUBLIC_KEY}" > "${SSH_KEY_PATH}"
fi

cleanup() {
  echo "===> Cleanup completed"
}

trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  }
}

########################################
# CHECKS
########################################

require_command qm

if [[ ! -f "${IMG_PATH}" ]]; then
  echo "ERROR: Image not found:"
  echo "${IMG_PATH}"
  exit 1
fi

if [[ ! -f "${SSH_KEY_PATH}" ]]; then
  echo "ERROR: SSH public key not found:"
  echo "${SSH_KEY_PATH}"
  exit 1
fi

if qm status "${VM_ID}" >/dev/null 2>&1; then
  echo "ERROR: VM ${VM_ID} already exists"
  exit 1
fi

########################################
# CREATE VM
########################################

echo "===> Creating VM ${VM_ID}"

qm create "${VM_ID}" \
  --name "${VM_NAME}" \
  --ostype l26 \
  --machine q35 \
  --bios ovmf \
  --memory "${MEMORY}" \
  --balloon "${BALLOON}" \
  --sockets "${SOCKETS}" \
  --cores "${CORES}" \
  --cpu "cputype=${CPU_TYPE}" \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --rng0 source=/dev/urandom \
  --serial0 socket \
  --vga serial0 \
  --net0 "virtio,bridge=${BRIDGE}"

########################################
# IMPORT DISK
########################################

echo "===> Importing disk"

qm importdisk \
  "${VM_ID}" \
  "${IMG_PATH}" \
  "${STORAGE}"

########################################
# ATTACH DISK
########################################

echo "===> Attaching disk"

qm set "${VM_ID}" \
  --scsihw virtio-scsi-single \
  --scsi0 "${STORAGE}:vm-${VM_ID}-disk-0,discard=on,iothread=1,ssd=1"

########################################
# EFI DISK
########################################

echo "===> Creating EFI disk"

qm set "${VM_ID}" \
  --efidisk0 "${STORAGE}:1,format=raw,efitype=4m,pre-enrolled-keys=1"

########################################
# CLOUD-INIT
########################################

echo "===> Configuring cloud-init"

qm set "${VM_ID}" \
  --ide2 "${STORAGE}:cloudinit"

qm set "${VM_ID}" \
  --boot order=scsi0

qm set "${VM_ID}" \
  --ciuser "${CI_USER}" \
  --sshkeys "${SSH_KEY_PATH}" \
  --ipconfig0 ip=dhcp

########################################
# RESIZE DISK
########################################

echo "===> Resizing disk to ${DISK_SIZE}"

qm resize "${VM_ID}" scsi0 "${DISK_SIZE}"

########################################
# ENABLE QEMU AGENT
########################################

echo "===> Starting VM for initial cloud-init cleanup"

qm start "${VM_ID}"

echo "===> Waiting for guest agent"

for i in {1..30}; do
  if qm guest ping "${VM_ID}" >/dev/null 2>&1; then
    break
  fi

  sleep 2
done

########################################
# CLEAN CLOUD-INIT STATE
########################################

echo "===> Cleaning cloud-init state"

qm guest exec "${VM_ID}" -- bash -c "cloud-init clean"

########################################
# SHUTDOWN VM
########################################

echo "===> Shutting down VM"

qm shutdown "${VM_ID}" --timeout 300

while qm status "${VM_ID}" | grep -q running; do
  sleep 2
done

########################################
# CONVERT TO TEMPLATE
########################################

echo "===> Converting VM to template"

qm template "${VM_ID}"

########################################
# FINAL INFO
########################################

echo
echo "========================================"
echo "Template created successfully"
echo "========================================"
echo
echo "VM ID:      ${VM_ID}"
echo "VM Name:    ${VM_NAME}"
echo "Storage:    ${STORAGE}"
echo "Disk Size:  ${DISK_SIZE}"
echo
echo "Clone example:"
echo
echo "qm clone ${VM_ID} 151  --name vm-151 --target proxmox --storage local-lvm --full"

