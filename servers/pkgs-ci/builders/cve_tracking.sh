#!/bin/bash

set -o errexit
set -o xtrace

WORKDIR=/workspace
BRANCH=${BRANCH:-master}

URL=https://172.18.170.22:8443/raw/cve-tracker-config.git/${BRANCH}/start.sh
START_SH=${WORKDIR}/start.sh

sudo apt install -y \
  git \
  python3-dev \
  python3-pip

sudo mkdir -p "${WORKDIR}"

sudo chown -R "${USER}" "${WORKDIR}"
sudo chown -R "${USER}" /var/www/html

mkdir -p "${WORKDIR}/html"
mkdir -p "${WORKDIR}/persistent"

if [[ ! -f "${START_SH}" ]]; then
  curl -k "${URL}" -o "${START_SH}"
fi

cd "${WORKDIR}"
bash -o xtrace -o errexit "${START_SH}" once

