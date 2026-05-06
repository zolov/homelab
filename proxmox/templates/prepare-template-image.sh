#!/usr/bin/env bash

set -euo pipefail

: "${PASSWD:=ubuntu}"
: "${IMG_DIR:=/var/pve/vm/template}"
: "${IMG_EXT:=img}"
: "${NEW_EXT:=qcow2}"
: "${IMG_NAME:=noble-server-cloudimg-amd64}"
: "${IMG_PATH:=${IMG_DIR}/${IMG_NAME}.${IMG_EXT}}"
: "${NEW_PATH:=${IMG_DIR}/ubuntu-template.${NEW_EXT}}"
: "${IMG_URL:=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"

echo "===> Installing dependencies"
apt update
apt install libguestfs-tools dhcpcd-base wget -y


echo "===> Removing previous image"
rm -f "${NEW_PATH}"

echo "===> Downloading fresh ${IMG_NAME} image to ${IMG_DIR}"
mkdir -p "${IMG_DIR}"
wget -O "${IMG_PATH}" "${IMG_URL}"

echo "===> Customizing image located at ${IMG_PATH}"

virt-customize -a "${IMG_DIR}/${IMG_NAME}.${IMG_EXT}" --update --install qemu-guest-agent --install cloud-init \
 --root-password password:"${PASSWD}" \
 --run-command "echo -n > /etc/machine-id" \
 --run-command "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config" \
 --run-command "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
 --run-command 'systemctl enable qemu-guest-agent'

echo "===> Changing file image extension from ${IMG_EXT} to ${NEW_EXT}"
mv "${IMG_PATH}" "${NEW_PATH}"

echo "===> DONE: Prepared image is ready at ${NEW_PATH}"
