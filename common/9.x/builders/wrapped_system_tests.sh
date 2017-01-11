#!/bin/bash

set -ex

# Set statistics job-group properties for swarm tests

FUEL_STATS_HOST="fuel-collect-systest.infra.mirantis.net"
ANALYTICS_IP="fuel-stats-systest.infra.mirantis.net"

export FUEL_STATS_HOST="${FUEL_STATS_HOST}"
export ANALYTICS_IP="${ANALYTICS_IP}"


LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}

# fixme: move to macros
case "${LOCATION}" in
    # fixme: mirror.fuel-infra.org could point to brokem mirror
    # srt)
    #     MIRROR_HOST="osci-mirror-srt.srt.mirantis.net"
    #     ;;
    # msk)
    #     MIRROR_HOST="osci-mirror-msk.msk.mirantis.net"
    #     ;;
    # kha)
    #     MIRROR_HOST="osci-mirror-kha.kha.mirantis.net"
    #     LOCATION="hrk"
    #     ;;
    poz|bud|bud-ext|undef)
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"
        LOCATION="cz"
        ;;
    mnv|scc|sccext)
        MIRROR_HOST="mirror.seed-us1.fuel-infra.org"
        LOCATION="usa"
        ;;
    *)
        # MIRROR_HOST="mirror.fuel-infra.org"
        # fixme: mirror.fuel-infra.org could point to brokem mirror
        MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

esac



if [[ ! "${MIRROR_UBUNTU}" ]]; then

    if [ "${UBUNTU_MIRROR_ID}" = 'latest' ]; then
        UBUNTU_MIRROR_ID=$(curl -sSf "${MIRROR_HOST}/pkgs/snapshots/ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
    fi
    UBUNTU_MIRROR_URL="http://${MIRROR_HOST}/pkgs/snapshots/${UBUNTU_MIRROR_ID}/"

    UBUNTU_REPOS="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"

# todo: later ..
#    ENABLE_PROPOSED="${ENABLE_PROPOSED:-true}"
#
#    if [ "$ENABLE_PROPOSED" = true ]; then
#        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
#        UBUNTU_REPOS="$UBUNTU_REPOS|$UBUNTU_PROPOSED"
#    fi

    export MIRROR_UBUNTU="$UBUNTU_REPOS"

fi



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

# Adding upstream centos mirror
if [[ "${ENABLE_CENTOS_MIRROR:-false}" = true ]] ; then
    for _dn in  "os"        \
                "updates"   ; do
        __repo_url="http://${MIRROR_HOST}/pkgs/snapshots/${CENTOS_MIRROR_ID}/${_dn}/x86_64"
        __repo_name="centos-${_dn},${__repo_url}"
        UPDATE_FUEL_MIRROR="$(join "${__space}" "${UPDATE_FUEL_MIRROR}" "${__repo_url}" )"
        EXTRA_RPM_REPOS="$(join "${__pipe}" "${EXTRA_RPM_REPOS}" "${__repo_name}" )"
    done
fi

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

rm -rf logs/*

ENV_NAME="${ENV_PREFIX?}.${ENV_SUFFIX?}"
ENV_NAME="${ENV_NAME:0:68}"

# done for destroy step
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

# save name for destruction step
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK?}" -v --force-set-symlink -o "${WORKSPACE?}")

echo "Description string: ${TEST_GROUP?} on ${CUSTOM_VERSION?}"

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT:-false}

env

sh  -x "utils/jenkins/system_tests.sh"  \
    -t test                             \
    -w "${WORKSPACE}"                   \
    -e "${ENV_NAME}"                    \
    -o                                  \
    --group="${TEST_GROUP}"             \
    -i "${ISO_PATH}"

# remove env if not set verbosely to keep it

if [[ "${KEEP_ENV:-false}" = false ]] ; then
    source "${VENV_PATH}/bin/activate"
    dos.py erase "${ENV_NAME}"
fi
