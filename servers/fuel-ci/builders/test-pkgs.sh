#!/bin/bash

echo "STEP 2: run deployment test"

set -ex

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/"
        ;;
    poz|bud|bud-ext|budext|undef)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
        ;;
    mnv|scc|sccext)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/"
esac

export $(curl -sSf "${JENKINS_URL}job/${ENV_JOB}/lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt")
if [ "${UBUNTU_MIRROR_ID}" = 'latest' ]; then
    UBUNTU_MIRROR_ID=$(curl -sSf "${MIRROR_HOST}pkgs/snapshots/ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
fi
UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/snapshots/${UBUNTU_MIRROR_ID}/"

if [[ ! "${MIRROR_UBUNTU}" ]]; then
    MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"
    if [ "${ENABLE_PROPOSED:-false}" = 'true' ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
        MIRROR_UBUNTU="${MIRROR_UBUNTU}|${UBUNTU_PROPOSED}"
    fi
    export MIRROR_UBUNTU
fi

export SYSTEM_TESTS="${SYSTEST_ROOT}/utils/jenkins/system_tests.sh"
export LOGS_DIR=/home/jenkins/workspace/${JOB_NAME}/logs/${BUILD_NUMBER}

#test params
sh -x "${SYSTEM_TESTS}" \
  -w "${SYSTEST_ROOT}" \
  -V "${VENV_PATH}" \
  -i "${ISO_PATH}" \
  -t test \
  -e "${ENV_NAME}" \
  -o --group="${TEST_GROUP}"
