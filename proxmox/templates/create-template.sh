#!/usr/bin/env bash

set -Eeuo pipefail

RED='\e[31m'
GREEN='\e[32m'
NC='\e[0m' # No Color (Reset)

########################################
# LOAD ENV
########################################

ENV_FILE="$(dirname "$0")/.env"

if [[ -f "${ENV_FILE}" ]]; then
  echo -e "${GREEN}===> Loading ${ENV_FILE}${NC}"

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
  echo -e "${GREEN}===> Cleanup completed${NC}"
}

trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${RED}ERROR: Required command not found: $1 ${NC}" >&2
    exit 1
  }
}

########################################
# CHECKS
########################################

require_command qm

if [[ ! -f "${IMG_PATH}" ]]; then
  echo -e "${RED}ERROR: Image not found:${NC}"
  echo -e "${IMG_PATH}"
  exit 1
fi

if [[ ! -f "${SSH_KEY_PATH}" ]]; then
  echo -e "${RED}ERROR: SSH public key not found:${NC}"
  echo -e "${SSH_KEY_PATH}"
  exit 1
fi

if qm status "${VM_ID}" >/dev/null 2>&1; then
  echo -e "${RED}ERROR: VM ${VM_ID} already exists${NC}"
  exit 1
fi

########################################
# CREATE VM
########################################

echo -e "${GREEN}===> Creating VM ${VM_ID}${NC}"

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

echo -e "${GREEN}===> Importing disk${NC}"

qm importdisk \
  "${VM_ID}" \
  "${IMG_PATH}" \
  "${STORAGE}"

########################################
# ATTACH DISK
########################################

echo -e "${GREEN}===> Attaching disk${NC}"

qm set "${VM_ID}" \
  --scsihw virtio-scsi-single \
  --scsi0 "${STORAGE}:vm-${VM_ID}-disk-0,discard=on,iothread=1,ssd=1"

########################################
# EFI DISK
########################################

echo -e "${GREEN}===> Creating EFI disk${NC}"

qm set "${VM_ID}" \
  --efidisk0 "${STORAGE}:1,format=raw,efitype=4m,pre-enrolled-keys=1"

########################################
# CLOUD-INIT
########################################

echo -e "${GREEN}===> Configuring cloud-init${NC}"

qm set "${VM_ID}" \
  --ide2 "${STORAGE}:cloudinit"

qm set "${VM_ID}" \
  --boot order=scsi0

qm set "${VM_ID}" \
  --ciuser "${CI_USER}" \
  --sshkeys "${SSH_KEY_PATH}" \
  --ipconfig0 ip=dhcp,tag=10

########################################
# RESIZE DISK
########################################

echo -e "${GREEN}===> Resizing disk to ${DISK_SIZE}${NC}"

qm resize "${VM_ID}" scsi0 "${DISK_SIZE}"

########################################
# ENABLE QEMU AGENT
########################################

echo -e "${GREEN}===> Starting VM for initial cloud-init cleanup${NC}"

qm start "${VM_ID}"

echo -e "${GREEN}===> Waiting for guest agent${NC}"

for i in {1..30}; do
  if qm guest ping "${VM_ID}" >/dev/null 2>&1; then
    break
  fi

  sleep 2
done

########################################
# CLEAN CLOUD-INIT STATE
########################################

echo -e "${GREEN}===> Cleaning cloud-init state${NC}"

qm guest exec "${VM_ID}" -- bash -c "cloud-init clean"

########################################
# SHUTDOWN VM
########################################

echo -e "${GREEN}===> Shutting down VM${NC}"

qm shutdown "${VM_ID}" --timeout 300

while qm status "${VM_ID}" | grep -q running; do
  sleep 2
done

########################################
# CONVERT TO TEMPLATE
########################################

echo -e "${GREEN}===> Converting VM to template${NC}"

qm template "${VM_ID}"

########################################
# FINAL INFO
########################################

echo -e
echo -e "========================================${NC}"
echo -e "${GREEN}Template created successfully${NC}"
echo -e "========================================${NC}"
echo -e
echo -e "VM ID:      ${VM_ID}${NC}"
echo -e "VM Name:    ${VM_NAME}${NC}"
echo -e "Storage:    ${STORAGE}${NC}"
echo -e "Disk Size:  ${DISK_SIZE}${NC}"
echo -e
echo -e "Clone example:${NC}"
echo -e
echo -e "qm clone ${VM_ID} 151  --name vm-151 --target proxmox --storage local-lvm --full ${NC}"
echo -e "qm set 151 --net0 virtio,bridge=vmbr0,tag=10 ${NC}"

