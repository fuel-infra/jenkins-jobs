#!/bin/bash

set -ex

TEST_ISO_JOB_URL="${JENKINS_URL}job/${TEST_ISO_JOB}/"

#### Set statistics job-group properties for swarm tests ####

FUEL_STATS_HOST="fuel-collect-systest.infra.mirantis.net"
ANALYTICS_IP="fuel-stats-systest.infra.mirantis.net"

export FUEL_STATS_HOST="${FUEL_STATS_HOST}"
export ANALYTICS_IP="${ANALYTICS_IP}"

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    # fixme: uncomment after mirror will be in-sync
    # srt)
    #     MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/"
    #     ;;
    # msk)
    #     MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/"
    #     ;;
    # kha)
    #     MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/"
    #     ;;
    # poz)
    #     MIRROR_HOST="http://osci-mirror-poz.poz.mirantis.net/"
    #     ;;
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
        # fixme: after mirror will be in-sync
        # MIRROR_HOST="http://mirror.fuel-infra.org/"
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
esac

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

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"

    if [ "$ENABLE_PROPOSED" = true ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi

###################### Set extra DEB and RPM repos ####

if [[ -n "${RPM_LATEST}" ]]; then
    RPM_MIRROR="${MIRROR_HOST}mos-repos/centos/mos9.0-centos7/snapshots/"
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        RPM_PROPOSED="mos-proposed,${RPM_MIRROR}proposed-${RPM_LATEST}/x86_64"
        EXTRA_RPM_REPOS+="${RPM_PROPOSED}"
        UPDATE_FUEL_MIRROR="${RPM_MIRROR}proposed-${RPM_LATEST}/x86_64"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        RPM_UPDATES="mos-updates,${RPM_MIRROR}updates-${RPM_LATEST}/x86_64"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_UPDATES}"
        UPDATE_FUEL_MIRROR+="${RPM_MIRROR}updates-${RPM_LATEST}/x86_64"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        RPM_SECURITY="mos-security,${RPM_MIRROR}security-${RPM_LATEST}/x86_64"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_SECURITY}"
        UPDATE_FUEL_MIRROR+="${RPM_MIRROR}security-${RPM_LATEST}/x86_64"
    fi

    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER=true
fi

if [[ -n "${DEB_LATEST}" ]]; then
    DEB_MIRROR="${MIRROR_HOST}mos-repos/ubuntu/snapshots/9.0-${DEB_LATEST}"
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        DEB_PROPOSED="mos-proposed,deb ${DEB_MIRROR} mos9.0-proposed main restricted"
        EXTRA_DEB_REPOS+="${DEB_PROPOSED}"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        DEB_UPDATES="mos-updates,deb ${DEB_MIRROR} mos9.0-updates main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_UPDATES}"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        DEB_SECURITY="mos-security,deb ${DEB_MIRROR} mos9.0-security main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_SECURITY}"
    fi
    export EXTRA_DEB_REPOS
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
