#!/bin/bash

set -ex
## needed variables:
# MIRROR_ARTIFACT - aka PERESTROIKA mirror, example:
# ${JENKINS_URL}job/${ENV_JOB}/lastSuccessfulBuild/artifact/mirror_ubuntu_data.txt

export MIRROR_UBUNTU=$(curl -sSf "${MIRROR_ARTIFACT}")

export SYSTEM_TESTS="${SYSTEST_ROOT}/utils/jenkins/system_tests.sh"
export LOGS_DIR=/home/jenkins/workspace/${JOB_NAME}/logs/${BUILD_NUMBER}

# Check if custom test group is specified
if [[ ! -z "${CUSTOM_TEST_GROUP}" ]]; then
  export TEST_GROUP="${CUSTOM_TEST_GROUP}"
fi

#test params
VERSION_STRING=$(readlink ${ISO_PATH} | cut -d '-' -f 2-3)
echo "Description string: ${VERSION_STRING}"

sh -x "${SYSTEM_TESTS}" \
  -w "${SYSTEST_ROOT}/" \
  -V "${VENV_PATH}" \
  -i "${ISO_PATH}" \
  -t test \
  -e "${ENV_NAME}" \
  -o --group="${TEST_GROUP}"
