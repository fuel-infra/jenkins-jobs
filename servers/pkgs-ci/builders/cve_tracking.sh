#!/bin/bash

set -o errexit
set -o xtrace

trap on_exit EXIT

die() {
  cat << EOF

========================================
$@
========================================
EOF
  exit 1
}

on_exit() {
  if ${DROPLOCK}; then
    sudo rm -f "${LOCKFILE}" || true
  fi
  exit
}

WORKDIR=/workspace
BRANCH=${BRANCH:-master}

LOCKFILE=/var/run/cve-tracker.lock
DROPLOCK=false

URL=https://172.18.170.22:8443/raw/cve-tracker-config.git/${BRANCH}/start.sh
START_SH=${WORKDIR}/start.sh

if [[ -f "${LOCKFILE}" ]]; then
  die "Amother process already running, lockfile '${LOCKFILE}' found"
fi
DROPLOCK=true
sudo touch "${LOCKFILE}"

sudo apt install -y \
  git \
  python3-dev \
  python3-pip

sudo mkdir -p "${WORKDIR}"

sudo chown "${USER}" "${WORKDIR}"
sudo chown -R "${USER}" /var/www/html

mkdir -p "${WORKDIR}/html"
mkdir -p "${WORKDIR}/persistent"

if [[ ! -f "${START_SH}" ]]; then
  curl -k "${URL}" -o "${START_SH}"
fi

cd "${WORKDIR}"
bash -o xtrace -o errexit "${START_SH}" once

