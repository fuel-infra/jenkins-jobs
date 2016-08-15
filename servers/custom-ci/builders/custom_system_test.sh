#!/bin/bash

set -ex

if [[ "${NETWORK_MODE}" == "Neutron/VLAN" ]]; then
  export NEUTRON_ENABLE="true"
  export NEUTRON_SEGMENT_TYPE="vlan"
fi

if [[ "${NETWORK_MODE}" == "Neutron/GRE" ]]; then
  export NEUTRON_ENABLE="true"
  export NEUTRON_SEGMENT_TYPE="gre"
fi

if [[ "${NETWORK_MODE}" == "Neutron/VXLAN" ]]; then
  export NEUTRON_ENABLE="true"
  export NEUTRON_SEGMENT_TYPE="tun"
fi

# Checking gerrit commits for fuel-qa
if [[ "${fuel_qa_gerrit_commit}" != "none" ]] ; then
  for commit in ${fuel_qa_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-qa "${commit}" && git cherry-pick FETCH_HEAD
  done
fi

# Check if custom test group is specified
if [[ ! -z "${CUSTOM_TEST_GROUP}" ]]; then
  # Remove leading spaces from CUSTOM_TEST_GROUP
  TEST_GROUP="${CUSTOM_TEST_GROUP##"${CUSTOM_TEST_GROUP%%[![:space:]]*}"}"
  # Remove trailing spaces from CUSTOM_TEST_GROUP
  export TEST_GROUP="${TEST_GROUP%%"${TEST_GROUP##*[![:space:]]}"}"

  # Stop script execution to avoid incorrect command line construction
  # for running system tests if list of test groups contains space symbols
  if [[ "${TEST_GROUP}" =~ [[:space:]] ]]
  then
    echo "List of custom test groups must not contain space symbols." \
         "Please separate groups by commas" >&2
    exit 1
  fi
fi

rm -rf logs/*

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT}
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
echo "${ISO_PATH}"

# Fix parameters for ha_neutron_destructive test
if [[ "${TEST_GROUP}" == "ha_neutron_destructive" ]]; then
  export NEUTRON_ENABLE="true"
fi

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
export ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

export PATH_TO_CERT="${WORKSPACE}/${ENV_NAME}.crt"
export PATH_TO_PEM="${WORKSPACE}/${ENV_NAME}.pem"

export OPENSTACK_RELEASE="${OPENSTACK_RELEASE}"

echo "Description string: ${TEST_GROUP} on ${NODE_NAME}: ${ENV_NAME}"

sh -x "utils/jenkins/system_tests.sh" \
  -t test \
  -w "${WORKSPACE}" \
  -V "${VENV_PATH}" \
  -j "${JOB_NAME}" \
  -o --group="${TEST_GROUP}" \
  -i "${ISO_PATH}"
