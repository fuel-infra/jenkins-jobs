#!/bin/bash

set -ex

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

# Fetch params from snapshot job
if [[ ! "${SNAPSHOT_PARAMS_ID}" ]]; then
    SNAPSHOT_PARAMS_ID="lastSuccessfulBuild"
fi

curl -s "https://patching-ci.infra.mirantis.net/job/9.x.snapshot.params/${SNAPSHOT_PARAMS_ID}/artifact/snapshots.sh" > snapshots.sh

while read line ; do
 var_name=$(echo "${line}" | awk -F '=' '{print $1}')
 var_overwrite="$(join "_" "${var_name}" "$(to_uppercase "overwrite")")"
 if [[ ! -z ${!var_overwrite} ]]
 then
  declare ${var_name}="${!var_overwrite}"
 else
  eval "${line}"
 fi
done <snapshots.sh

### LOCATION CODE - use "guess-mirror builder"

# Adding Ubuntu deb repos to
# - MIRROR_UBUNTU - will be used for nodes in cluster
# UBUNTU_MIRROR_ID comes from snapshot.sh file
UBUNTU_MIRROR_URL="http://${MIRROR_HOST}/pkgs/snapshots/${UBUNTU_MIRROR_ID}/"
for __dn in "trusty"         \
            "trusty-updates" \
            "trusty-security"; do
    __repo="deb ${UBUNTU_MIRROR_URL} ${__dn} main universe multiverse"
    MIRROR_UBUNTU="$(join "${__pipe}" "${MIRROR_UBUNTU}" "${__repo}")"
done

if [ "${ENABLE_UBUNTU_MIRROR_PROPOSED}" = true ]; then
    __repo="deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
    MIRROR_UBUNTU="$(join "${__pipe}" "${MIRROR_UBUNTU}" "${__repo}")"
fi


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
        UPDATE_FUEL_MIRROR="$(join "${__space}" "${UPDATE_FUEL_MIRROR}" "${__repo_url}" )"
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

echo "<============> REPOS PARSING RESULTS <============>"
echo "MAGNET_LINK: ${MAGNET_LINK}"
echo "UPDATE_MASTER: ${UPDATE_MASTER}"
echo "UPDATE_FUEL_MIRROR: ${UPDATE_FUEL_MIRROR}"
echo "MIRROR_UBUNTU: ${MIRROR_UBUNTU}"
echo "EXTRA_RPM_REPOS: ${EXTRA_RPM_REPOS}"
echo "EXTRA_DEB_REPOS: ${EXTRA_DEB_REPOS}"
echo "MIRROR_HOST: ${MIRROR_HOST}"
echo "<=================================================>"

cat > systest_repos.jenkins-injectfile <<EOF
MAGNET_LINK=${MAGNET_LINK}
UPDATE_MASTER=${UPDATE_MASTER}
UPDATE_FUEL_MIRROR=${UPDATE_FUEL_MIRROR}
MIRROR_UBUNTU=${MIRROR_UBUNTU}
EXTRA_RPM_REPOS=${EXTRA_RPM_REPOS}
EXTRA_DEB_REPOS=${EXTRA_DEB_REPOS}
MIRROR_HOST=${MIRROR_HOST}
EOF
