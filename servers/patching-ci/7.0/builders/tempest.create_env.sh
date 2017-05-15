#!/bin/bash

set -ex

# Init default vars
ENV_NAME=${ENV_NAME:-maintenance_env_7.0}
FUEL_QA_VER=${FUEL_QA_VER:-stable/7.0}
BONDING=${BONDING:-false}
ERASE_PREV_ENV=${ERASE_PREV_ENV:-true}
GROUP=${GROUP:-tempest_ceph_services}
DISABLE_SSL=${DISABLE_SSL:-false}
SLAVE_NODE_MEMORY=${SLAVE_NODE_MEMORY:-4096}
OPENSTACK_RELEASE=${OPENSTACK_RELEASE:-ubuntu}
SKIP_INSTALL_ENV=${SKIP_INSTALL_ENV:-false}

if $SKIP_INSTALL_ENV ; then
    exit 0
fi

# Activate virtualenv
source "${VENV_PATH}/bin/activate"

# Download and link ISO
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

if [ -z "$ISO_PATH" ]
then
    echo "Please download ISO and define env variable ISO_PATH"
    exit 1
fi

# erase previous environments
if ${ERASE_PREV_ENV} ; then
    dos.py list | tail -n+3 | xargs -I {} dos.py erase {}
fi

if [ -n "${FILE}" ]; then
    cat "mos-ci-deployment-scripts/jenkins-job-builder/maintenance/helpers/${FILE}" > fuelweb_test/tests/test_services.py
fi

###################### Get MIRROR_UBUNTU ###############

MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
CENTOS_UPDATE_HOST="http://pkg-updates.fuel-infra.org/centos6/"
TEST_ISO_JOB_URL="${TEST_ISO_JOB_URL:-https://product-ci.infra.mirantis.net/job/7.0.test_all/}"

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
    RPM_MIRROR="${MIRROR_HOST}mos-repos/centos/mos7.0-centos6-fuel/snapshots/"
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
    DEB_MIRROR="${MIRROR_HOST}mos-repos/ubuntu/snapshots/7.0-${DEB_LATEST}"
    if [[ "${ENABLE_PROPOSED}" == "true" ]]; then
        DEB_PROPOSED="mos-proposed,deb ${DEB_MIRROR} mos7.0-proposed main restricted"
        EXTRA_DEB_REPOS+="${DEB_PROPOSED}"
    fi
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        DEB_UPDATES="mos-updates,deb ${DEB_MIRROR} mos7.0-updates main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_UPDATES}"
    fi
    if [[ "${ENABLE_SECURITY}" == "true" ]]; then
        DEB_SECURITY="mos-security,deb ${DEB_MIRROR} mos7.0-security main restricted"
        if [[ -n "${EXTRA_DEB_REPOS}" ]]; then
            EXTRA_DEB_REPOS+="|"
        fi
        EXTRA_DEB_REPOS+="${DEB_SECURITY}"
    fi
    export EXTRA_DEB_REPOS
fi


# create new environment
# more time can be required to deploy env
export DEPLOYMENT_TIMEOUT=10000
export ENV_NAME=$ENV_NAME
export ADMIN_NODE_MEMORY=4096
export SLAVE_NODE_CPU=3
export SLAVE_NODE_MEMORY=$SLAVE_NODE_MEMORY
export DISABLE_SSL=$DISABLE_SSL
export NOVA_QUOTAS_ENABLED=true
export KVM_USE=true
export BONDING=$BONDING
export OPENSTACK_RELEASE=$OPENSTACK_RELEASE

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -w "$(pwd)" -e "$ENV_NAME" -o --group="$GROUP" -i "$ISO_PATH"