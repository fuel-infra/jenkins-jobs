#!/bin/bash

set -ex

UBUNTU_DIST=${UBUNTU_DIST:-trusty}

# Set proper Openstack Release
if [[ ${OPENSTACK_RELEASE} == 'centos' ]]; then
	export OPENSTACK_RELEASE="CentOS"
elif [[ ${OPENSTACK_RELEASE} == 'ubuntu' ]]; then
	export OPENSTACK_RELEASE="Ubuntu"
fi

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}

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
    poz)
        MIRROR_HOST="http://osci-mirror-poz.poz.mirantis.net/pkgs/snapshots/"
        ;;
    bud)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/snapshots/"
        ;;
    bud-ext)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/snapshots/"
        ;;
    mnv|scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/snapshots/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/pkgs/snapshots/"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest-stable)
            UBUNTU_MIRROR_ID="$(curl -fsS "${TEST_ISO_JOB_URL}lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" | awk -F '[ =]' '{print $NF}')"
            ;;
        latest)
            UBUNTU_MIRROR_ID=$(curl -sSf "${MIRROR_HOST}ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
            ;;
    esac
    UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"

    MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"
    if [ "${ENABLE_PROPOSED:-false}" = 'true' ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
        MIRROR_UBUNTU="${MIRROR_UBUNTU}|${UBUNTU_PROPOSED}"
    fi
    export MIRROR_UBUNTU
fi

export TIMESTAMP=$(date +%y%m%d%H%M)
export ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${TIMESTAMP}"
export ENV_NAME="${ENV_NAME:0:68}"
export FUEL_STATS_ENABLED="false"

echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

rm -rf logs/*

ISO_PATH=$(seedclient-wrapper -d -m "${BASE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

export MAKE_SNAPSHOT="true"

sh -x "BASE/utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}/BASE" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"

echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

export MAKE_SNAPSHOT="false"

export TARBALL_PATH=$(seedclient-wrapper -d -m "${UPGRADE_TARBALL_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${TARBALL_PATH}" | cut -d '-' -f 2-4)
echo "Description string: ${VERSION_STRING}"

export UPGRADE_FUEL_FROM=$(basename "${ISO_PATH}" | cut -d '-' -f 2 | sed s/.iso//g)
export UPGRADE_FUEL_TO=$(basename "${TARBALL_PATH}" | cut -d '-' -f 2)

# Use -k to reuse environment
sh -x "UPGRADE/utils/jenkins/system_tests.sh" -k -t test -w "${WORKSPACE}/UPGRADE" -e "${ENV_NAME}" -o --group="${UPGRADE_TEST_GROUP}" -i "${ISO_PATH}"
