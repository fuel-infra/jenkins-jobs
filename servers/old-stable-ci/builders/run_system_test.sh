#!/bin/bash

set -ex

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID:-latest}

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
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
fi

rm -rf logs/*

export VENV_PATH=${VENV_PATH:-/home/jenkins/venv-nailgun-tests}

ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

sh -x "utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"
