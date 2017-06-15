#!/bin/bash

set -ex

# Input:
# ENV_NAME
# SNAPSHOT_PARAMS_ID
# MAGNET_LINK
# {UBUNTU,CENTOS}_MIRROR_ID
# MOS_UBUNTU_MIRROR_ID
# MOS_CENTOS_{OS,PROPOSED,UPDATES,HOLDBACK,SECURITY,HOTFIX}_MIRROR_ID
# ENABLE_UBUNTU_MIRROR_PROPOSED
# ENABLE_MOS_{UBUNTU,CENTOS}_{OS,PROPOSED,UPDATES,HOLDBACK,SECURITY,HOTFIX}
# UPDATE_MASTER_VIA_MOS_MU
# INTERFACE_MODEL
# ERASE_ENV_PREFIX
# DISABLE_SSL
# CONFIG_PATH
# VENV_PATH
# SNAPSHOT_NAME
# NOVA_QUOTAS


if [[ -n "${SNAPSHOT_PARAMS_ID}" ]]; then
    source <(curl -s "https://patching-ci.infra.mirantis.net/job/9.x.snapshot.params/${SNAPSHOT_PARAMS_ID}/artifact/snapshots.sh")
fi

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK?}" -v --force-set-symlink -o "${WORKSPACE}")

source "${VENV_PATH?}/bin/activate"

dos.py list | tail -n+3 | xargs -I {} dos.py destroy {}
if [[ -n "${ERASE_ENV_PREFIX}" ]]; then
    dos.py list | tail -n+3 | grep "${ERASE_ENV_PREFIX}" | xargs -I {} dos.py erase {}
fi

# # # # # # # # # Repos detection # # # # # # # # # # # # # # # # # # # # # # # # # #
# TODO: replace with /common/9.x/builders/wrapped_system_test.sh when it been done as macros

MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

export FUEL_STATS_HOST="fuel-collect-systest.infra.mirantis.net"
export ANALYTICS_IP="fuel-stats-systest.infra.mirantis.net"

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}
case "${LOCATION}" in
    poz|bud|bud-ext|undef)
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"
        LOCATION="cz"
        ;;
    mnv|scc|sccext)
        MIRROR_HOST="mirror.seed-us1.fuel-infra.org"
        LOCATION="usa"
        ;;
    *)
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"
esac


UBUNTU_MIRROR_URL="http://${MIRROR_HOST}/pkgs/snapshots/${UBUNTU_MIRROR_ID}/"
UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"
if [ "${ENABLE_UBUNTU_MIRROR_PROPOSED}" = true ]; then
    UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
    UBUNTU_REPOS="${UBUNTU_REPOS}|${UBUNTU_PROPOSED}"
fi

export MIRROR_UBUNTU="${UBUNTU_REPOS}"


function join() {
    local __sep="${1}"
    local __head="${2}"
    local __tail="${3}"

    if [[ -n "${__head}" ]]; then
        echo "${__head}${__sep}${__tail}"
    else
        echo "${__tail}"
    fi
}

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

__space=' '
__pipe='|'


# Adding snapshots of upstream CentOS repositories os, updates and extras
# using snapshot ID to the UPDATE_FUEL_MIRROR variable

if [[ ! -z ${CENTOS_MIRROR_ID} ]]; then
    for __repo in "os"      \
                  "extras"  \
                  "updates" ; do
        __url="http://${MIRROR_HOST}/pkgs/snapshots/${CENTOS_MIRROR_ID}/${__repo}/x86_64"
        UPDATE_FUEL_MIRROR="$(join "${__space}" "${UPDATE_FUEL_MIRROR}" "${__url}" )"
    done
fi

# Adding MOS rpm repos to
# - UPDATE_FUEL_MIRROR - will be used for master node
# - EXTRA_RPM_REPOS - will be used for nodes in cluster

for _dn in  "os"        \
            "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_MOS_CENTOS_$(to_uppercase "${_dn}")"
    if [[ "${!__enable_ptr}" = true ]] ; then
        # a pointer to variable name which holds repo id
        __repo_id_ptr="MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID"
        __repo_url="http://${MIRROR_HOST}/mos-repos/centos/mos9.0-centos7/snapshots/${!__repo_id_ptr}/x86_64"
        __repo_name="mos-${_dn},${__repo_url}"
        UPDATE_FUEL_MIRROR="$(join "${__space}" "${UPDATE_FUEL_MIRROR}" "${__repo_url}" )"
        EXTRA_RPM_REPOS="$(join "${__pipe}" "${EXTRA_RPM_REPOS}" "${__repo_name}" )"
    fi
done

# UPDATE_MASTER=true in case when we have set some repos
# otherwise there will be no reason to start updating without any repos to update from

if [[ -n "${UPDATE_FUEL_MIRROR}" ]] ; then
    UPDATE_MASTER=${UPDATE_MASTER:-true}
fi

# Adding MOS deb repos to
# - EXTRA_DEB_REPOS - will be used for nodes in cluster

for _dn in  "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_MOS_UBUNTU_$(to_uppercase "${_dn}")"
    # a pointer to variable name which holds repo id
    __repo_id_ptr="MOS_UBUNTU_MIRROR_ID"
    __repo_url="http://${MIRROR_HOST}/mos-repos/ubuntu/snapshots/${!__repo_id_ptr}"
    if [[ "${!__enable_ptr}" = true ]] ; then
        __repo_name="mos-${_dn},deb ${__repo_url} mos9.0-${_dn} main restricted"
        EXTRA_DEB_REPOS="$(join "${__pipe}" "${EXTRA_DEB_REPOS}" "${__repo_name}")"
    fi
done


export UPDATE_FUEL_MIRROR   # for fuel-qa
export UPDATE_MASTER        # for fuel-qa
export EXTRA_RPM_REPOS      # for fuel-qa
export EXTRA_DEB_REPOS      # for fuel-qa


# # # # # # # # # Tempest conf preparation # # # # # # # # # # # # # # # # # # # # # # # # # #
pushd mos-ci-deployment-scripts
CONFIG_FILE=$(basename "${CONFIG_PATH}")
CONFIG_NAME="${CONFIG_FILE%.*}"

KVM_USE=true
PLUGINS_CONFIG_PATH=$(pwd)/plugins.yaml
DEPLOYMENT_TIMEOUT=10000
NOVA_QUOTAS_ENABLED="${NOVA_QUOTAS}"

INTERFACE_PREFIX_CHANGE=true
if [ "${INTERFACE_MODEL?}" = 'virtio' ] ; then
    # Virtio network interfaces have names eth0..eth5
    # (rather than default names - enp0s3..enp0s8)
    for i in {0..5}; do
        declare "IFACE_$i=eth$i"
        export "IFACE_$i"
    done
fi

export INTERFACE_PREFIX_CHANGE ISO_PATH ENV_NAME DISABLE_SSL KVM_USE INTERFACE_MODEL PLUGINS_CONFIG_PATH DEPLOYMENT_TIMEOUT NOVA_QUOTAS_ENABLED

pip install dpath --upgrade

cp test_deploy_env.py ../system_test/tests/
cp -r templates/* ../system_test/tests_templates/
cp "${CONFIG_PATH}" ../system_test/tests_templates/tests_configs/

../run_system_test.py run 'system_test.deploy_env' --with-config "${CONFIG_NAME}"
popd

dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}"

deactivate

