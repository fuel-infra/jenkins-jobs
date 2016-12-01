#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

############################
# Some useful functions
############################

get_deb_snapshot() {
    # Remove quotes from input argument(s)
    local INPUT
    INPUT=( $(tr -d \" <<< "${@}") )
    # Ubuntu repos may have format "[deb] URL DISTRO COMPONENT1 [COMPONENTN][,PRIORITY]"
    local deb_prefix=''
    if [ "${INPUT[0]}" = "deb" ]; then
        deb_prefix='deb '
        unset INPUT[0]
    fi
    # Assign values to variables.
    # The last variable - 'components' - will also contain priority if any, but
    # it does not matter here, it will be returned as is
    read -r repo_url dist_name components <<< "${INPUT[@]}"
    # Remove trailing slash
    repo_url=${repo_url%/}
    # Cut version
    repo_version=${repo_url##*/}
    repo_url=${repo_url%/*}
    # Get snapshot
    local snapshot=$(curl -fLsS "${repo_url}/snapshots/${repo_version}-latest.target.txt" | sed '1p; d')
    echo "${deb_prefix}${repo_url}/snapshots/${snapshot} ${dist_name} ${components}"
}

get_rpm_snapshot() {
    # Remove quotes from input argument
    local INPUT
    INPUT=$(tr -d \" <<< "${1}")
    # Centos repos may have format "[NAME,]URL[,PRIORITY]"
    read -r repo_name repo_url priority <<< "${INPUT//,/ }"
    if [ -z "${repo_url}" ]; then
        # Repo does not have extra parameters
        repo_url=${repo_name}
        unset repo_name
    elif [ -z "${priority}" ]; then
        # Two parameters... Do we have repo name or priority?
        if [[ "${repo_url}" =~ ^[0-9]+$ ]]; then
            # repo_url contain only numbers - it is priority
            priority=${repo_url}
            repo_url=${repo_name}
            unset repo_name
        fi
    fi
    # Remove trailing slash
    repo_url="${repo_url%/}"
    # Remove architecture
    repo_url="${repo_url%/*}"
    # Cut component
    repo_component="${repo_url##*/}"
    repo_url=${repo_url%/*}
    # Get snapshot
    local snapshot="$(curl -fLsS "${repo_url}/snapshots/${repo_component}-latest.target.txt" | sed '1p; d')"
    echo "${repo_name:+${repo_name},}${repo_url}/snapshots/${snapshot}/x86_64${priority:+,${priority}}"
}

# Perestroika uses a lot of Gerrit parameters, so in case of using Zuul, you can
# mimic Gerrit by setting gerrit-specific parameters by job parameter function.
# Look for 'parameter-function':
#   http://docs.openstack.org/infra/zuul/zuul.html#jobs
# Another option is setting gerrit-specific parameters from zuul-specific ones
# in (this) job script.

# Required parameters
: "${GERRIT_PROJECT?}"
if [ -n "${GERRIT_REFSPEC}" ]; then
    # CR-specific
    : "${GERRIT_CHANGE_NUMBER?}"
    : "${GERRIT_BRANCH?}"
else
    # ref-updated
    : "${GERRIT_REFNAME?}"
fi

# Gerrit parameters are required by perestroika builder to get info about CR
: "${GERRIT_HOST?}"
: "${GERRIT_PORT?}"
: "${GERRIT_USER?}"

############################
# Guess mirror host
############################

if [ -z "${MIRROR_HOST}" ]; then
    MIRROR_HOST=mirror.fuel-infra.org
fi

############################
# Project-specific parameters
############################

# Required by perestroika to define GPG key filename (only!)
: "${PROJECT_NAME?}"
: "${PROJECT_VERSION?}"

############################
# Global parameters
############################

# Required by perestroika builder to compose extra repository URLs
export REMOTE_REPO_HOST=${MIRROR_HOST}

# Required by perestroika builder to compose source project name
: "${SRC_PROJECT_PATH?}"

# Required by perestroika builder to choose build system
: "${DIST?}"

# Required by perestroika as directory containig build specs
: "${SPEC_PREFIX_PATH?}"

# Required by perestroika builder to set build dependency repositories
: "${REPO_REQUEST_PATH_PREFIX?}"

# Distro name for DEB packages
: "${DEB_DIST_NAME?}"

# Base repository pathes
: "${BASE_DEB_REPO_PATH?}"
: "${BASE_RPM_REPO_PATH?}"

# Get latest snapshots
SNAPSHOT_DEB=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_DEB_REPO_PATH}/snapshots/${PROJECT_VERSION}-latest.target.txt" | sed '1p; d')
SNAPSHOT_RPM_OS=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/snapshots/os-latest.target.txt" | sed '1p; d')
SNAPSHOT_RPM_HOTFIX=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/snapshots/hotfix-latest.target.txt" | sed '1p; d')
SNAPSHOT_RPM_UPDATES=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/snapshots/updates-latest.target.txt" | sed '1p; d')
SNAPSHOT_RPM_PROPOSED=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/snapshots/proposed-latest.target.txt" | sed '1p; d')
SNAPSHOT_RPM_SECURITY=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/snapshots/security-latest.target.txt" | sed '1p; d')
SNAPSHOT_RPM_HOLDBACK=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/snapshots/holdback-latest.target.txt" | sed '1p; d')

# Repository pathes for builder (for build dependencies)
DEB_REPO_PATH=${BASE_DEB_REPO_PATH}/snapshots/${SNAPSHOT_DEB}
RPM_OS_REPO_PATH=${BASE_RPM_REPO_PATH}/snapshots/${SNAPSHOT_RPM_OS}
RPM_HOTFIX_REPO_PATH=${BASE_RPM_REPO_PATH}/snapshots/${SNAPSHOT_RPM_HOTFIX}
RPM_UPDATES_REPO_PATH=${BASE_RPM_REPO_PATH}/snapshots/${SNAPSHOT_RPM_UPDATES}
RPM_PROPOSED_REPO_PATH=${BASE_RPM_REPO_PATH}/snapshots/${SNAPSHOT_RPM_PROPOSED}
RPM_SECURITY_REPO_PATH=${BASE_RPM_REPO_PATH}/snapshots/${SNAPSHOT_RPM_SECURITY}
RPM_HOLDBACK_REPO_PATH=${BASE_RPM_REPO_PATH}/snapshots/${SNAPSHOT_RPM_HOLDBACK}

# DEB-specific parameters
export DEB_DIST_NAME DEB_REPO_PATH

# RPM-specific parameters
export RPM_OS_REPO_PATH RPM_HOTFIX_REPO_PATH RPM_UPDATES_REPO_PATH RPM_PROPOSED_REPO_PATH RPM_SECURITY_REPO_PATH RPM_HOLDBACK_REPO_PATH

# Set parameters specific to project(s)
case "${GERRIT_PROJECT}" in
    openstack/fuel-*|openstack/network-checker|openstack/python-fuelclient|openstack/solar|openstack/shotgun|openstack/timmy|openstack/tuning-box )
        IS_FUEL=true
        export IS_OPENSTACK=false
        unset SPEC_PROJECT
        ;;
    openstack/*|openstack-build/*-build )
        export IS_OPENSTACK=true
        # Check parameters required by perestroika builder to compose spec project name
        : "${SPEC_PROJECT_PATH?}"
        : "${SPEC_PROJECT_SUFFIX?}"
        ;;
    * )
        export IS_OPENSTACK=false
        export SRC_PROJECT_PATH="${GERRIT_PROJECT%/*}"
        unset SPEC_PROJECT
        ;;
esac

# Extra repos containing build dependecies
case ${PKG_TYPE?} in
    deb)
        if [ ! -z "${ADDITIONAL_EXTRAREPO_DEB}" ] ; then
            export EXTRAREPO="http://${MIRROR_HOST}/${DEB_REPO_PATH} ${DEB_DIST_NAME} main restricted|${ADDITIONAL_EXTRAREPO_DEB}"
        else
            export EXTRAREPO="http://${MIRROR_HOST}/${DEB_REPO_PATH} ${DEB_DIST_NAME} main restricted"
        fi
        ;;
    rpm)
        if [ ! -z "${ADDITIONAL_EXTRAREPO_RPM}" ] ; then
            export EXTRAREPO="deps,http://${MIRROR_HOST}/${RPM_OS_REPO_PATH}/x86_64|${ADDITIONAL_EXTRAREPO_RPM}"
        else
            export EXTRAREPO="deps,http://${MIRROR_HOST}/${RPM_OS_REPO_PATH}/x86_64"
        fi
        ;;
esac

############################
# Cleanup from previous builds
############################

rm -vf buildresult.params tests.envfile systest.params

############################
# Build package
############################

# Save time of build start
BUILD_START_AT=$(date -u +%s)

# ... and build a package
if [ "${IS_FUEL:-false}" = "true" ]; then
    bash -x "build-fuel-${PKG_TYPE}.sh"
else
    bash -x "build-${PKG_TYPE}.sh"
fi

# Print build job duration
BUILD_FINISH_AT=$(date -u +%s)
BUILD_DURATION=$(( BUILD_FINISH_AT - BUILD_START_AT ))
H=$(( BUILD_DURATION / 3600 ))      # Hours
M=$(( BUILD_DURATION % 3600 / 60 )) # Minutes
S=$(( BUILD_DURATION % 60 ))        # Seconds

echo '##############################'
printf "Package building took %02d:%02d:%02d\n" ${H} ${M} ${S}
echo '##############################'
