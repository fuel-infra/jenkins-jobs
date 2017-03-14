#!/bin/bash

WORKDIR=/workspace
export WORKDIR

apt-get install -y git

cd ${WORKDIR}
git clone git://172.18.170.22/cve-tracker-config.git
rm -f ${WORKDIR}/start.sh
cp ${WORKDIR}/cve-tracker-config/start.sh ${WORKDIR}
${WORKDIR}/start.sh once

