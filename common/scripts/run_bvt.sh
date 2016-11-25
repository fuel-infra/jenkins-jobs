#!/bin/bash

set -ex

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID:-latest}
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/pkgs/snapshots/"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/pkgs/snapshots/"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/pkgs/snapshots/"
        ;;
    poz|bud|budext|cz)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/snapshots/"
        ;;
    scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/snapshots/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/pkgs/snapshots/"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    if [ "${UBUNTU_MIRROR_ID}" = 'latest' ]; then
        UBUNTU_MIRROR_ID=$(curl -sSf "${MIRROR_HOST}ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
    fi
    UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"

    ENABLE_PROPOSED="${ENABLE_PROPOSED:-true}"

    if [ "$ENABLE_PROPOSED" = true ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi

############# Done getting MIRROR_UBUNTU ###############

rm -rf logs/*

export VENV_PATH=${VENV_PATH:-/home/jenkins/venv-nailgun-tests}

ENV_NAME=${ENV_PREFIX}${ENV_SUFFIX}
ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

ISO_PATH=$(seedclient.py -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
FUEL_QA_COMMIT=$(git -C "${WORKSPACE}" rev-parse HEAD)

ISO_NAME_REPORT=$(basename "${ISO_PATH}")
ISO_NAME_REPORT="${ISO_NAME_REPORT//.iso/}"
echo "BUILD=${ISO_NAME_REPORT}" > "${WORKSPACE}/iso_report.properties"

# Create files which will be published as artifacts
echo "MAGNET_LINK=${MAGNET_LINK}" > magnet_link.txt
echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt
echo "FUEL_QA_COMMIT=${FUEL_QA_COMMIT}" > fuel_qa_commit.txt

sh -x "utils/jenkins/system_tests.sh" \
    -t test \
    -w "${WORKSPACE}" \
    -e "${ENV_NAME}" \
    -o --group="${TEST_GROUP}" \
    -i "${ISO_PATH}"
