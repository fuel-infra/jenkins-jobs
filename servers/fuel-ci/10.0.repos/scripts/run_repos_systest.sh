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
FUEL_MIRROR_HOST="packages.fuel-infra.org"

# FIXME(kozhukalov): use mirantis mirrors once they are ready
MIRROR_UBUNTU=http://archive.ubuntu.com/ubuntu

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest)
            MIRROR_UBUNTU="$(curl "http://${MIRROR_HOST}/pkgs/ubuntu-latest.htm")"
            ;;
        *)
            MIRROR_UBUNTU="http://${MIRROR_HOST}/pkgs/${UBUNTU_MIRROR_ID}/"
    esac
fi

MOS_UBUNTU_VERSION=${MOS_UBUNTU_VERSION:-master}
if [[ "${MOS_UBUNTU_VERSION}" = "master" ]]; then
    MOS_UBUNTU_REPO_PREFIX="mos-master"
else
    MOS_UBUNTU_REPO_PREFIX="mos${MOS_UBUNTU_VERSION}"
fi
MOS_CENTOS_VERSION=${MOS_CENTOS_VERSION:-master}
if [[ "${MOS_CENTOS_VERSION}" = "master" ]]; then
    MOS_CENTOS_REPO_PREFIX="mos-master"
else
    MOS_CENTOS_REPO_PREFIX="mos${MOS_CENTOS_VERSION}"
fi

FUEL_UBUNTU_VERSION=${FUEL_UBUNTU_VERSION:-master-xenial}
FUEL_UBUNTU_REPO_PREFIX=${FUEL_UBUNTU_VERSION}
FUEL_CENTOS_VERSION=${FUEL_CENTOS_VERSION:-master}
FUEL_CENTOS_REPO_PREFIX=${FUEL_CENTOS_VERSION}


function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}


################################
# PREPARE YAML FILES
################################

export RPM_REPOS_YAML=${RPM_REPOS_YAML:-$WORKSPACE/rpm_repos.yaml}
export DEB_REPOS_YAML=${DEB_REPOS_YAML:-$WORKSPACE/deb_repos.yaml}

cat > "${DEB_REPOS_YAML}" <<EOF
---
-
  type: "deb"
  name: "ubuntu"
  uri: "${MIRROR_UBUNTU}"
  suite: "xenial"
  section: "main universe multiverse"
  priority: null
-
  type: "deb"
  name: "ubuntu-updates"
  uri: "${MIRROR_UBUNTU}"
  suite: "xenial-updates"
  section: "main universe multiverse"
  priority: null
-
  type: "deb"
  name: "ubuntu-security"
  uri: "${MIRROR_UBUNTU}"
  suite: "xenial-security"
  section: "main universe multiverse"
  priority: null
EOF


ENABLE_PROPOSED="${ENABLE_PROPOSED:-false}"
if [[ "$ENABLE_PROPOSED" = true ]]; then
cat >> "${DEB_REPOS_YAML}" <<EOF
-
  type: "deb"
  name: "ubuntu-proposed"
  uri: "${MIRROR_UBUNTU}"
  suite: "xenial"
  section: "main universe multiverse"
  priority: null
EOF
fi

__mos_repo_id_ptr="MOS_UBUNTU_MIRROR_ID"
__mos_repo_url="http://${MIRROR_HOST}/mos-repos/xenial/snapshots/${!__mos_repo_id_ptr}"

cat >> "${DEB_REPOS_YAML}" <<EOF
-
  type: "deb"
  name: "mos"
  uri: "${__mos_repo_url}"
  suite: "${MOS_UBUNTU_REPO_PREFIX}"
  section: "main restricted"
  priority: 1100
EOF

for _dn in  "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_MOS_UBUNTU_$(to_uppercase "${_dn}")"
    case ${_dn} in
        updates)
            _priority=1110
            ;;
        security)
            _priority=1120
            ;;
        holdback)
            _priority=1130
            ;;
        hotfix)
            _priority=1140
            ;;
        proposed)
            _priority=1150
            ;;
        *)
            _priority=1100
            ;;
    esac
    # a pointer to variable name which holds repo id
    if [[ "${!__enable_ptr}" = true ]] ; then
        cat >> "${DEB_REPOS_YAML}" <<EOF
-
  type: "deb"
  name: "mos-${_dn}"
  uri: "${__mos_repo_url}"
  suite: "${MOS_UBUNTU_REPO_PREFIX}-${_dn}"
  section: "main restricted"
  priority: ${_priority}
EOF
    fi
done


__fuel_repo_id_ptr="FUEL_UBUNTU_MIRROR_ID"
__fuel_repo_url="http://${FUEL_MIRROR_HOST}/repositories/ubuntu/snapshots/${!__fuel_repo_id_ptr}"

cat >> "${DEB_REPOS_YAML}" <<EOF
-
  type: "deb"
  name: "fuel"
  uri: "${__fuel_repo_url}"
  suite: "${FUEL_UBUNTU_REPO_PREFIX}"
  section: "main restricted"
  priority: 1200
EOF


for _dn in  "proposed"  \
            "updates"   \
            "holdback"  \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_FUEL_UBUNTU_$(to_uppercase "${_dn}")"
    case ${_dn} in
        updates)
            _priority=1210
            ;;
        security)
            _priority=1220
            ;;
        holdback)
            _priority=1230
            ;;
        proposed)
            _priority=1250
            ;;
        *)
            _priority=1200
            ;;
    esac
    # a pointer to variable name which holds repo id
    if [[ "${!__enable_ptr}" = true ]] ; then
        cat >> "${DEB_REPOS_YAML}" <<EOF
-
  type: "deb"
  name: "fuel-${_dn}"
  uri: "${__fuel_repo_url}"
  suite: "${FUEL_UBUNTU_REPO_PREFIX}-${_dn}"
  section: "main restricted"
  priority: ${_priority}
EOF
    fi
done


echo "---" > "${RPM_REPOS_YAML}"
for _dn in  "os"        \
            "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    # a pointer to variable name which holds value of enable flag for this dist name
    __enable_ptr="ENABLE_MOS_CENTOS_$(to_uppercase "${_dn}")"
    case ${_dn} in
        updates)
            _priority=9
            ;;
        security)
            _priority=8
            ;;
        holdback)
            _priority=7
            ;;
        hotfix)
            _priority=6
            ;;
        proposed)
            _priority=5
            ;;
        *)
            _priority=10
            ;;
    esac
    if [[ "${!__enable_ptr}" = true ]] ; then
        # a pointer to variable name which holds repo id
        __repo_id_ptr="MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID"
        __repo_url="http://${MIRROR_HOST}/mos-repos/centos/${MOS_CENTOS_REPO_PREFIX}-centos7/snapshots/${!__repo_id_ptr}/x86_64"
        cat >> "${RPM_REPOS_YAML}" <<EOF
-
  type: "rpm"
  name: "mos-${_dn}"
  priority: ${_priority}
  uri: "${__repo_url}"
EOF
    fi
done

__fuel_repo_id_ptr="FUEL_CENTOS_OS_MIRROR_ID"
__fuel_repo_url="http://${FUEL_MIRROR_HOST}/repositories/centos/${FUEL_CENTOS_REPO_PREFIX}-centos7/snapshots/${!__fuel_repo_id_ptr}/x86_64"

cat >> "${RPM_REPOS_YAML}" <<EOF
-
  type: "rpm"
  name: "fuel-os"
  priority: 4
  uri: "${__fuel_repo_url}"
EOF


echo "${DEB_REPOS_YAML}"
cat "${DEB_REPOS_YAML}"

echo "${RPM_REPOS_YAML}"
cat "${RPM_REPOS_YAML}"


FUEL_RELEASE_URL="http://${MIRROR_HOST}/mos-repos/centos/${MOS_CENTOS_REPO_PREFIX}-centos7/snapshots/${MOS_CENTOS_OS_MIRROR_ID}/x86_64/Packages/fuel-release-*.noarch.rpm"
FUEL_RELEASE_FILE_NAME=$(basename "${FUEL_RELEASE_URL}")
export FUEL_RELEASE_PATH="$WORKSPACE/fuel-release.noarch.rpm"

echo "fuel-release package: ${FUEL_RELEASE_URL}"

# shellcheck disable=SC2086
wget --no-parent \
    -r \
    -nd \
    -e robots=off \
    -A "${FUEL_RELEASE_FILE_NAME}" \
    "$(dirname "${FUEL_RELEASE_URL}")/" &&
  mv ${FUEL_RELEASE_FILE_NAME} "${FUEL_RELEASE_PATH}"

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

rm -rf logs/*

ENV_NAME="${ENV_PREFIX?}.${ENV_SUFFIX?}"
ENV_NAME="${ENV_NAME:0:68}"

# done for destroy step
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

# system_tests.sh script requires ISO, so we create fake one
ISO_PATH="${WORKSPACE}/workaround.empty.iso"
echo "remove the line when iso argument becomes optional in fuel-devops" > "${ISO_PATH}"

echo "Description string: ${TEST_GROUP?} on ${CUSTOM_VERSION?}"

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT:-false}
export PATH_TO_CERT=${WORKSPACE}/${ENV_NAME}.crt
export PATH_TO_PEM=${WORKSPACE}/${ENV_NAME}.pem

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
