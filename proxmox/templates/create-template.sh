#!/usr/bin/env bash

set -euo pipefail

: "${CI_USER:=ubuntu}"
: "${PASSWD:=ubuntu}"
: "${VM_ID:=5000}"
: "${VM_NAME:=ubuntu-template}"
: "${STORAGE:=local-lvm}"
: "${IMG_DIR:=/var/pve/vm/template}"
: "${IMG_NAME:=ubuntu-template.qcow2}"
: "${IMG_PATH:=${IMG_DIR}/${IMG_NAME}}"
: "${MEMORY:=2048}"
: "${CORES:=2}"
: "${DISK_SIZE:=10G}"
: "${BRIDGE:=vmbr0}"
: "${CPU_TYPE:=host}"

if [ ! -f "${IMG_PATH}" ]; then
  echo "ERROR: Prepared image not found: ${IMG_PATH}" >&2
  echo "Run prepare-template-image.sh first, or set IMG_PATH to the prepared image." >&2
  exit 1
fi

echo "===> Creating VM ${VM_ID}"
qm create "${VM_ID}" \
  --name "${VM_NAME}" \
  --memory "${MEMORY}" \
  --cores "${CORES}" \
  --net0 "virtio,bridge=${BRIDGE}"

echo "===> Importing disk"
qm importdisk "${VM_ID}" "${IMG_PATH}" "${STORAGE}"

echo "===> Attaching disk"
qm set "${VM_ID}" \
  --scsihw virtio-scsi-pci \
  --scsi0 "${STORAGE}:vm-${VM_ID}-disk-0,cache=writeback,discard=on,ssd=1"

echo "===> Adding cloud-init"
qm set "${VM_ID}" --boot c --bootdisk scsi0
qm set "${VM_ID}" --boot order=scsi0
qm set "${VM_ID}" --ide1 "${STORAGE}":cloudinit

qm set "${VM_ID}" --agent enabled=1

echo "===> Resizing disk +${DISK_SIZE}"
qm resize "${VM_ID}" scsi0 "+${DISK_SIZE}"

qm set "${VM_ID}" --serial0 socket --vga serial0
qm set "${VM_ID}" --cpu "cputype=${CPU_TYPE}"
qm set "${VM_ID}" --ostype l26

qm set "${VM_ID}" \
  --ciuser "${CI_USER}" \
  --cipassword "${PASSWD}" \
  --ciupgrade 1 \
  --sshkeys ~/.ssh/homelab.pub \
  --ipconfig0 ip=dhcp \
  --nameserver 192.168.8.1 \
  --searchdomain cloud.local


echo "===> Converting VM to template"
qm template "${VM_ID}"
qm rescan --vmid "${VM_ID}"
qm config "${VM_ID}"

echo "===> DONE: Template ${VM_NAME} (${VM_ID}) is ready"
