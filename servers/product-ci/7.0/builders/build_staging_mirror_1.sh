#!/bin/bash

set -ex

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt
# get stable ubuntu mirror
LATEST_MIRROR_ID=$(curl -s http://perestroika-repo-tst.infra.mirantis.net/osci/mos/7.0.target.txt | head -1)
# re-define MIRROR_UBUNTU_ROOT value from fuel-main make system
export MIRROR_UBUNTU_ROOT="/osci/mos/${LATEST_MIRROR_ID}/cluster/base/trusty/"
# re-define MIRROR_FUEL value from fuel-main make system
export MIRROR_FUEL="http://perestroika-repo-tst.infra.mirantis.net/osci/mos/${LATEST_MIRROR_ID}/fuel/base/centos6/"
osci-mirrors/fuel_master_mirror_vc.sh
echo "USE_STABLE_MOS_FOR_STAGING = ${USE_STABLE_MOS_FOR_STAGING}" >> ${WORKSPACE:-"."}/mirror_staging.txt
echo FINISHED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" >> ci_status_params.txt
