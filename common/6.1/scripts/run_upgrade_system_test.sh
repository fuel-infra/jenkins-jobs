#!/bin/bash

set -ex

TEST_ISO_JOB_URL="${TEST_ISO_JOB_URL:-https://product-ci.infra.mirantis.net/job/7.0.test_all/}"

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

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
    poz)
        MIRROR_HOST="http://osci-mirror-poz.poz.mirantis.net/"
        ;;
    bud)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
        ;;
    bud-ext)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
        ;;
    mnv|scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/"
esac

# Set proper Openstack Release
if [[ ${OPENSTACK_RELEASE} == 'centos' ]]; then
	export OPENSTACK_RELEASE=CentOS
elif [[ ${OPENSTACK_RELEASE} == 'ubuntu' ]]; then
	export OPENSTACK_RELEASE=Ubuntu
fi

export CONNECTION_STRING='qemu+tcp://127.0.0.1:16509/system'
export ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}
export ENV_NAME=${ENV_NAME:0:68}
export FUEL_STATS_ENABLED=false

rm -rf logs/*

ISO_PATH=$(seedclient-wrapper -d -m "${BASE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

export MAKE_SNAPSHOT=true

sh -x "BASE/utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}/BASE" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"

echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

export MAKE_SNAPSHOT=false

export TARBALL_PATH=$(seedclient-wrapper -d -m "${UPGRADE_TARBALL_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${TARBALL_PATH}" | cut -d '-' -f 2-4)
echo "Description string: ${VERSION_STRING}"

export UPGRADE_FUEL_FROM=$(basename "${ISO_PATH}" | cut -d '-' -f 2 | sed s/.iso//g)
export UPGRADE_FUEL_TO=$(basename "${TARBALL_PATH}" | cut -d '-' -f 2)

export VENV_PATH='/home/jenkins/qa-venv-6.1'

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest-stable)
            UBUNTU_MIRROR_ID="$(curl -fsS "${TEST_ISO_JOB_URL}lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" | awk -F '[ =]' '{print $NF}')"
            UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
            ;;
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}pkgs/ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"
fi

###################### Set extra DEB and RPM repos ####

if [[ -n "${RPM_LATEST}" ]]; then
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        RPM_PROPOSED="mos-proposed,${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/proposed"
        EXTRA_RPM_REPOS+="${RPM_PROPOSED}"
        UPDATE_FUEL_MIRROR="${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/proposed"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        RPM_UPDATES="mos-updates,${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/updates"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_UPDATES}"
        UPDATE_FUEL_MIRROR+="${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/updates"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        RPM_SECURITY="mos-security,${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/security"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_SECURITY}"
        UPDATE_FUEL_MIRROR+="${MIRROR_HOST}mos/${RPM_LATEST}/mos6.1/security"
    fi
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER=true
fi

if [[ -n "${DEB_LATEST}" ]]; then
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        DEB_PROPOSED="mos-proposed,deb ${MIRROR_HOST}mos/${DEB_LATEST} mos6.1-proposed main restricted"
        EXTRA_DEB_REPOS+="${DEB_PROPOSED}"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        DEB_UPDATES="mos-updates,deb ${MIRROR_HOST}mos/${DEB_LATEST} mos6.1-updates main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_UPDATES}"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        DEB_SECURITY="mos-security,deb ${MIRROR_HOST}mos/${DEB_LATEST} mos6.1-security main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_SECURITY}"
    fi
    export EXTRA_DEB_REPOS
fi

# Use -k to reuse environment
sh -x "UPGRADE/utils/jenkins/system_tests.sh" -k -t test -w "${WORKSPACE}/UPGRADE" -e "${ENV_NAME}" -o --group="${UPGRADE_TEST_GROUP}" -i "${ISO_PATH}"
