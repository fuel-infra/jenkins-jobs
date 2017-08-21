#!/bin/bash

set -ex

unset MAGNET_LINK
unset UPDATE_MASTER
unset UPDATE_FUEL_MIRROR
unset EXTRA_RPM_REPOS
unset EXTRA_DEB_REPOS

# Set proper Openstack Release
if [[ ${OPENSTACK_RELEASE} == 'centos' ]]; then
    export OPENSTACK_RELEASE="CentOS"
elif [[ ${OPENSTACK_RELEASE} == 'ubuntu' ]]; then
    export OPENSTACK_RELEASE="Ubuntu"
fi

###################### Set extra 6.1 DEB and RPM repos ####

RPM_UPDATES="${MIRROR_HOST}mos/snapshots/centos-6-latest/mos6.1/updates"
RPM_SECURITY="${MIRROR_HOST}mos/snapshots/centos-6-latest/mos6.1/security"
export EXTRA_RPM_REPOS="mos-updates,${RPM_UPDATES}|mos-security,${RPM_SECURITY}"
export UPDATE_FUEL_MIRROR="${RPM_UPDATES} ${RPM_SECURITY}"
export UPDATE_MASTER=true

DEB_UPDATES="mos-updates,deb ${MIRROR_HOST}mos/snapshots/ubuntu-latest mos6.1-updates main restricted"
DEB_SECURITY="mos-security,deb ${MIRROR_HOST}mos/snapshots/ubuntu-latest mos6.1-security main restricted"
export EXTRA_DEB_REPOS="${DEB_UPDATES}|${DEB_SECURITY}"

export TIMESTAMP=$(date +%y%m%d%H%M)
export ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${TIMESTAMP}"
export ENV_NAME="${ENV_NAME:0:68}"
export FUEL_STATS_ENABLED="false"

echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

rm -rf logs/*

ISO_PATH=$(seedclient-wrapper -d -m "${BASE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

export MAKE_SNAPSHOT="true"

sh -x "BASE/utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}/BASE" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"

echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

