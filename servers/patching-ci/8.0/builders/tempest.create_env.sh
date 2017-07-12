#!/bin/bash

set -ex

# Input:
# MAGNET_LINK
# ENV_NAME
# UPGRADE_TARBALL_MAGNET_LINK
# {DEB,RPM}_LATEST
# UBUNTU_MIRROR_ID
# ENABLE_{PROPOSED,SECURITY,UPDATES,UPDATE_CENTOS}
# ERASE_ENV_PREFIX
# DISABLE_SSL
# FUEL_QA_VER
# FILE
# GROUP
# BONDING
# UPDATE_CENTOS
# OPENSTACK_RELEASE
# SLAVE_NODE_MEMORY

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

source "${VENV_PATH?}/bin/activate"

dos.py list | tail -n+3 | xargs -I {} dos.py destroy {}
if [[ -n "${ERASE_ENV_PREFIX}" ]]; then
    dos.py list | tail -n+3 | grep "${ERASE_ENV_PREFIX}" | xargs -I {} dos.py erase {}
fi

if [ -n "${FILE}" ]; then
    cat "mos-ci-deployment-scripts/jenkins-job-builder/maintenance/helpers/${FILE}" > fuelweb_test/tests/test_services.py
fi

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}
CENTOS_UPDATE_HOST="http://pkg-updates.fuel-infra.org/centos7/"

case "${LOCATION}" in
    mnv|scc)
        MIRROR_HOST="http://us.mirror.fuel-infra.org/"
        ;;
    *)
        MIRROR_HOST="http://eu.mirror.fuel-infra.org/"
esac


###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}pkgs/ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}pkgs/${UBUNTU_MIRROR_ID}/"
    esac

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"

    if [ "$ENABLE_UBUNTU_PROPOSED" = true ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi

###################### Set extra DEB and RPM repos ####

if [[ -n "${RPM_LATEST}" ]]; then
    RPM_MIRROR="${MIRROR_HOST}mos-repos/centos/mos8.0-centos7-fuel/snapshots/"
    if [[ "${ENABLE_MOS_PROPOSED}" == "true" ]]; then
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
    if [[ "${ENABLE_UPDATE_CENTOS}" == "true" ]]; then
        RPM_UPDATE_CENTOS="centos-security,${CENTOS_UPDATE_HOST}"
        if [[ -n "${EXTRA_RPM_REPOS}" ]]; then
            EXTRA_RPM_REPOS+="|"
            UPDATE_FUEL_MIRROR+=" "
        fi
        EXTRA_RPM_REPOS+="${RPM_UPDATE_CENTOS}"
        UPDATE_FUEL_MIRROR+="${CENTOS_UPDATE_HOST}"
    fi
    export EXTRA_RPM_REPOS
    export UPDATE_FUEL_MIRROR
    export UPDATE_MASTER=true
fi

if [[ -n "${DEB_LATEST}" ]]; then
    DEB_MIRROR="${MIRROR_HOST}mos-repos/ubuntu/snapshots/8.0-${DEB_LATEST}"
    if [[ "${ENABLE_MOS_PROPOSED}" == "true" ]]; then
        DEB_PROPOSED="mos-proposed,deb ${DEB_MIRROR} mos8.0-proposed main restricted"
        EXTRA_DEB_REPOS+="${DEB_PROPOSED}"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        DEB_UPDATES="mos-updates,deb ${DEB_MIRROR} mos8.0-updates main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_UPDATES}"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        DEB_SECURITY="mos-security,deb ${DEB_MIRROR} mos8.0-security main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_SECURITY}"
    fi
    export EXTRA_DEB_REPOS
fi

export DEPLOYMENT_TIMEOUT=10000
export ENV_NAME
export ADMIN_NODE_MEMORY=4096
export SLAVE_NODE_CPU=3
export SLAVE_NODE_MEMORY
export DISABLE_SSL
export NOVA_QUOTAS_ENABLED=true
export KVM_USE=true
export BONDING
export OPENSTACK_RELEASE

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -w "$(pwd)" -e "${ENV_NAME}" -o --group="${GROUP}" -i "${ISO_PATH}"

deactivate

