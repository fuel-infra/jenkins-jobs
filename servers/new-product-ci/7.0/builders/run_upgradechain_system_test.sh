#!/bin/bash

set -ex

# Set proper Openstack Release
if [[ ${OPENSTACK_RELEASE} == 'centos' ]]; then
	export OPENSTACK_RELEASE=CentOS
elif [[ ${OPENSTACK_RELEASE} == 'ubuntu' ]]; then
	export OPENSTACK_RELEASE=Ubuntu
fi

export CONNECTION_STRING='qemu+tcp://127.0.0.1:16509/system'
export ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}
export ENV_NAME=${ENV_NAME:0:68}
export FUEL_STATS_ENABLED=false

rm -rf logs/*

ISO_PATH=$(seedclient-wrapper -d -m "${BASE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

export MAKE_SNAPSHOT=true
export TEST_GROUP='prepare_upgrade_env'

sh -x "BASE/utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}/BASE" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"

echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

export TARBALL_PATH=$(seedclient-wrapper -d -m "${BASE_UPGRADE_TARBALL_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename ${TARBALL_PATH} | cut -d '-' -f 2)
echo "Description string: ${VERSION_STRING}"

export UPGRADE_FUEL_FROM=6.0
export UPGRADE_FUEL_TO=6.1

export DEVOPS_DB_NAME='devops'
export DEVOPS_DB_USER='devops'
export DEVOPS_DB_PASSWORD='devops'
export VENV_PATH=/home/jenkins/venv-nailgun-tests-2.9
export UPGRADE_TEST_GROUP='upgrade_first_stage'

# Use -k to reuse environment
sh -x "BASE_UPGRADED/utils/jenkins/system_tests.sh" -k -t test -w "${WORKSPACE}/BASE_UPGRADED" -e "${ENV_NAME}" -o --group="${UPGRADE_TEST_GROUP}" -i "${ISO_PATH}"

# The next upgrade step

export TARBALL_PATH=$(seedclient-wrapper -d -m "${UPGRADE_TARBALL_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename ${TARBALL_PATH} | cut -d '-' -f 2-4)
echo "Description string: ${VERSION_STRING}"

export UPGRADE_FUEL_FROM=6.1
export UPGRADE_FUEL_TO=7.0

export DEVOPS_DB_NAME='devops'
export DEVOPS_DB_USER='devops'
export DEVOPS_DB_PASSWORD='devops'
export VENV_PATH=/home/jenkins/venv-nailgun-tests-2.9
export UPGRADE_TEST_GROUP='upgrade_second_stage'

# Use -k to reuse environment
sh -x "UPGRADE/utils/jenkins/system_tests.sh" -k -t test -w "${WORKSPACE}/UPGRADE" -e "${ENV_NAME}" -o --group="${UPGRADE_TEST_GROUP}" -i "${ISO_PATH}"

