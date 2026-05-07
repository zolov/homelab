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
: "${IMG_DIR:=/var/lib/vz/template/cache}"
: "${IMG_NAME:=noble-server-cloudimg-amd64.img}"
: "${IMG_URL:=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"

: "${WORK_IMG_NAME:=ubuntu-24.04-base.img}"

IMG_PATH="${IMG_DIR}/${IMG_NAME}"
WORK_IMG_PATH="${IMG_DIR}/${WORK_IMG_NAME}"

########################################
# HELPERS
########################################

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

require_command wget
require_command virt-customize
require_command qemu-img

########################################
# INSTALL DEPENDENCIES
########################################

echo "===> Installing dependencies"

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
  libguestfs-tools \
  wget

########################################
# DOWNLOAD IMAGE
########################################

echo "===> Preparing directories"

mkdir -p "${IMG_DIR}"

echo "===> Downloading Ubuntu cloud image"

wget -q --show-progress -O "${IMG_PATH}" "${IMG_URL}"

########################################
# VALIDATE IMAGE
########################################

echo "===> Validating image format"

qemu-img info "${IMG_PATH}"

########################################
# CREATE WORKING IMAGE
########################################

echo "===> Creating working qcow2 image"

rm -f "${WORK_IMG_PATH}"

qemu-img convert \
  -f qcow2 \
  -O qcow2 \
  "${IMG_PATH}" \
  "${WORK_IMG_PATH}"

########################################
# CUSTOMIZE IMAGE
########################################

echo "===> Customizing image"

virt-customize \
  -a "${WORK_IMG_PATH}" \
  --install qemu-guest-agent --install cloud-init \
  --run-command 'truncate -s 0 /etc/machine-id' \
  --run-command 'rm -f /var/lib/dbus/machine-id' \
  --run-command 'ln -s /etc/machine-id /var/lib/dbus/machine-id' \
  --run-command 'systemctl enable qemu-guest-agent' \
  --run-command 'cloud-init clean'

########################################
# FINAL INFO
########################################

echo
echo "========================================"
echo "Ubuntu cloud image prepared successfully"
echo "========================================"
echo
echo "Image path:"
echo "${WORK_IMG_PATH}"
echo
