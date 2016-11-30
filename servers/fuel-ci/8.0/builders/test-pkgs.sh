#!/bin/bash

set -ex

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_DIST="trusty"

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

curl -sSf "${JENKINS_URL}job/${ENV_JOB}/lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" > ubuntu_mirror_id.txt
source ubuntu_mirror_id.txt # -> UBUNTU_MIRROR_ID
case "${UBUNTU_MIRROR_ID}" in
    latest)
        UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}pkgs/ubuntu-latest.htm)"
        ;;
    *)
        UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
esac

MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"
if [ "${ENABLE_PROPOSED:-false}" = 'true' ]; then
    UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
    MIRROR_UBUNTU="${MIRROR_UBUNTU}|${UBUNTU_PROPOSED}"
fi
export MIRROR_UBUNTU

export SYSTEM_TESTS="${SYSTEST_ROOT}/utils/jenkins/system_tests.sh"
export LOGS_DIR=/home/jenkins/workspace/${JOB_NAME}/logs/${BUILD_NUMBER}

#test params

VERSION_STRING=$(readlink "${ISO_PATH}" | cut -d '-' -f 2-4)
echo "Description string: ${VERSION_STRING}"

sh -x "${SYSTEM_TESTS}" -w "${SYSTEST_ROOT}" -V "${VENV_PATH}" -i "${ISO_PATH}" -t test -e "${ENV_NAME}" -o --group="${TEST_GROUP}"
