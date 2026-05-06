#!/usr/bin/env bash

set -euo pipefail

: "${PASSWD:=debian}"
: "${IMG_DIR:=/var/lib/vz/template/iso}"
: "${IMG_NAME:=debian-13-generic-amd64.qcow2}"
: "${IMG_PATH:=${IMG_DIR}/${IMG_NAME}}"
: "${IMG_URL:=https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2}"

echo "===> Installing dependencies"
apt update
apt install libguestfs-tools dhcpcd-base wget -y

echo "===> Downloading fresh ${IMG_NAME} image to ${IMG_DIR}"
mkdir -p "${IMG_DIR}"
rm -f "${IMG_PATH}"
wget -O "${IMG_PATH}" "${IMG_URL}"

echo "===> Customizing image located at ${IMG_PATH}"
LIBGUESTFS_BACKEND=direct DEBIAN_FRONTEND=noninteractive virt-customize -v -x -a "${IMG_PATH}" \
  --run-command "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config" \
  --run-command "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
  --run-command 'echo "nameserver 8.8.8.8" > /etc/resolv.conf' \
  --run-command 'ping -c 3 8.8.8.8' \
  --run-command 'ping -c 3 google.com' \
  --install qemu-guest-agent,cloud-init \
  --run-command 'systemctl enable qemu-guest-agent' \
  --root-password "password:${PASSWD}"

echo "===> DONE: Prepared image is ready at ${IMG_PATH}"
