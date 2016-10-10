#!/bin/bash

set -ex

# link from https://mirantis.jira.com/wiki/display/PRD/9.0+release
MAGNET_LINK='magnet:?xt=urn:btih:bfec808dd71ff42c5613a3527733d9012bb1fabc&dn=MirantisOpenStack-9.0.iso&tr=http%3A%2F%2Ftracker01-bud.infra.mirantis.net%3A8080%2Fannounce&tr=http%3A%2F%2Ftracker01-scc.infra.mirantis.net%3A8080%2Fannounce&tr=http%3A%2F%2Ftracker01-msk.infra.mirantis.net%3A8080%2Fannounce&ws=http%3A%2F%2Fvault.infra.mirantis.net%2FMirantisOpenStack-9.0.iso'

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
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
fi

rm -rf logs/*

# refresh volumes in case of changes
virsh pool-refresh default

# debug info: show all volumes
virsh vol-list --details default

virsh vol-delete nessus.qcow2 --pool default || true
virsh vol-clone nessus_orig.qcow2 nessus.qcow2 --pool default

ENV_NAME="${ENV_PREFIX:0:68}"

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

export MAKE_SNAPSHOT=false

sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"
