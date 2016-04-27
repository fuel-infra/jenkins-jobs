#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

############################
# Some useful functions
############################

get_deb_snapshot() {
    # Debian repos may have format "URL DISTRO COMPONENT1 [COMPONENTN]"
    # Remove quotes and assign values to variables
    local deb_repo
    deb_repo=$(tr -d \" <<< "${@}")
    read -r repo_url dist_name components <<< "${deb_repo}"
    # Remove trailing slash
    repo_url=${repo_url%/}
    local snapshot
    snapshot=$(curl -fLsS "${repo_url}.target.txt" | head -1)
    echo "${repo_url%/*}/${snapshot}${dist_name:+ ${dist_name}}${components:+ ${components}}"
}

get_rpm_snapshot() {
    # Remove quotes
    local repo_url
    repo_url=$(tr -d \" <<< "${1}")
    # Remove trailing slash
    repo_url=${repo_url%/}
    # Remove architecture
    repo_url=${repo_url%/*}
    local snapshot
    snapshot=$(curl -fLsS "${repo_url}.target.txt" | head -1)
    echo "${repo_url%/*}/${snapshot}/x86_64"
}

# Perestroika uses a lot of Gerrit parameters, so in case of using Zuul, you can
# mimic Gerrit by setting gerrit-specific parameters by job parameter function.
# Look for 'parameter-function':
#   http://docs.openstack.org/infra/zuul/zuul.html#jobs
# Another option is setting gerrit-specific parameters from zuul-specific ones
# in (this) job script.

# Required parameters
: "${GERRIT_PROJECT?}"
: "${GERRIT_CHANGE_NUMBER?}"

if [ -n "${GERRIT_REFSPEC}" ]; then
    # CR-specific
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
SNAPSHOT_DEB=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_DEB_REPO_PATH}/${PROJECT_VERSION}.target.txt" | head -1)
SNAPSHOT_RPM_OS=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/os.target.txt" | head -1 || :)
SNAPSHOT_RPM_UPDATES=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/updates.target.txt" | head -1 || :)
SNAPSHOT_RPM_PROPOSED=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/proposed.target.txt" | head -1 || :)
SNAPSHOT_RPM_SECURITY=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/security.target.txt" | head -1 || :)
SNAPSHOT_RPM_HOLDBACK=$(curl -fLsS "http://${MIRROR_HOST}/${BASE_RPM_REPO_PATH}/holdback.target.txt" | head -1 || :)

# Repository pathes for builder (for build dependencies)
DEB_REPO_PATH=${BASE_DEB_REPO_PATH}/${SNAPSHOT_DEB}
RPM_OS_REPO_PATH=${BASE_RPM_REPO_PATH}/${SNAPSHOT_RPM_OS:-os}
RPM_UPDATES_REPO_PATH=${BASE_RPM_REPO_PATH}/${SNAPSHOT_RPM_UPDATES:-updates}
RPM_PROPOSED_REPO_PATH=${BASE_RPM_REPO_PATH}/${SNAPSHOT_RPM_PROPOSED:-proposed}
RPM_SECURITY_REPO_PATH=${BASE_RPM_REPO_PATH}/${SNAPSHOT_RPM_SECURITY:-security}
RPM_HOLDBACK_REPO_PATH=${BASE_RPM_REPO_PATH}/${SNAPSHOT_RPM_HOLDBACK:-holdback}

# DEB-specific parameters
export DEB_DIST_NAME DEB_REPO_PATH

# RPM-specific parameters
export RPM_OS_REPO_PATH RPM_UPDATES_REPO_PATH RPM_PROPOSED_REPO_PATH RPM_SECURITY_REPO_PATH RPM_HOLDBACK_REPO_PATH

# Set parameters specific to project(s)
case "${GERRIT_PROJECT}" in
    openstack/fuel-*|openstack/network-checker|openstack/python-fuelclient|openstack/solar|openstack/shotgun|openstack/tuning-box )
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
        unset SPEC_PROJECT
        ;;
esac

# Extra repos containing build dependecies
case ${PKG_TYPE?} in
    deb)
        export EXTRAREPO="http://${MIRROR_HOST}/${DEB_REPO_PATH} ${DEB_DIST_NAME} main restricted"
        ;;
    rpm)
        export EXTRAREPO="deps,http://${MIRROR_HOST}/${RPM_OS_REPO_PATH}/x86_64"
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
