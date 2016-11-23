#!/bin/bash

set -ex

TEST_ISO_JOB_URL="${JENKINS_URL}job/${TEST_ISO_JOB}/"
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

#### Set statistics job-group properties for swarm tests ####

# Temporary disabled due to https://bugs.launchpad.net/fuel/+bug/1605734
# FUEL_STATS_HOST="fuel-collect-systest.infra.mirantis.net"
# ANALYTICS_IP="fuel-stats-systest.infra.mirantis.net"
# export FUEL_STATS_HOST="${FUEL_STATS_HOST}"
# export ANALYTICS_IP="${ANALYTICS_IP}"

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/pkgs/"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/pkgs/"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/pkgs/"
        ;;
    poz)
        MIRROR_HOST="http://osci-mirror-poz.poz.mirantis.net/pkgs/"
        ;;
    bud)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/"
        ;;
    bud-ext)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/"
        ;;
    mnv|scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/pkgs/"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest-stable)
            UBUNTU_MIRROR_ID="$(curl -fsS "${TEST_ISO_JOB_URL}lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" | awk -F '[ =]' '{print $NF}')"
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
            ;;
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
    esac

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"

    if [ "$ENABLE_PROPOSED" = true ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi

rm -rf logs/*

ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${ISO_PATH}" | \
    sed -n -e 's/^.*\(fuel\)\(-community\|-gerrit\)\?-\([0-9.]\+\(-[a-z]\+\)\?-[0-9]\+\).*/\3/p')
echo "Description string: $TEST_GROUP on $VERSION_STRING"

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT:-false}

sh -x "utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"
