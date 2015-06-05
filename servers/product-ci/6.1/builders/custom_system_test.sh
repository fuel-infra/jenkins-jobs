#!/bin/bash

set -ex

# Checking gerrit commits for fuel-qa
if [[ "${fuel_qa_gerrit_commit}" != "none" ]] ; then
  for commit in ${fuel_qa_gerrit_commit} ; do
    git fetch https://review.openstack.org/stackforge/fuel-qa "${commit}" && git cherry-pick FETCH_HEAD
  done
fi

# Check if custom test group is specified
if [[ ! -z "${CUSTOM_TEST_GROUP}" ]]; then
  export TEST_GROUP="${CUSTOM_TEST_GROUP}"
fi

export VENV_PATH="/home/jenkins/venv-nailgun-tests-2.9"
rm -rf logs/*

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT}
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
echo "${ISO_PATH}"

# Fix parameters for ha_neutron_destructive test
if [[ "${TEST_GROUP}" == "ha_neutron_destructive" ]]; then
  export NEUTRON_ENABLE="true"
fi

export ENV_NAME="6.1.custom.system_test.${TEST_GROUP}.${BUILD_NUMBER}"
export OPENSTACK_RELASE="${OPENSTACK_RELEASE}"

echo "Description string: ${TEST_GROUP} on ${NODE_NAME}: ${ENV_NAME}"

sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}" -V "${VENV_PATH}" -j "${JOB_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"
