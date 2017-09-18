#!/bin/bash

set -o errexit
set -o xtrace

WORKDIR=/workspace
BRANCH=${BRANCH:-master}

URL=https://172.18.170.22:8443/raw/cve-tracker-config.git/${BRANCH}/start.sh
START_SH=${WORKDIR}/start.sh

apt install -y \
  git \
  python3-dev \
  python3-pip

mkdir -p "${WORKDIR}/html"
mkdir -p "${WORKDIR}/persistent"

rm -f ${START_SH} || true
curl -k "${URL}" -o "${START_SH}"

cd ${WORKDIR}
bash -o xtrace -o errexit "${START_SH}" once

