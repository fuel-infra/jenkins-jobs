#!/bin/bash

set -ex

export MIRROR_UBUNTU="$(curl -sSf "${JENKINS_URL}job/${ENV_JOB}/lastSuccessfulBuild/artifact/mirror_ubuntu_data.txt")"

export SYSTEM_TESTS="${SYSTEST_ROOT}/utils/jenkins/system_tests.sh"
export LOGS_DIR=/home/jenkins/workspace/${JOB_NAME}/logs/${BUILD_NUMBER}

#test params

VERSION_STRING=`readlink ${ISO_PATH} | cut -d '-' -f 2-4`
echo "Description string: ${VERSION_STRING}"

sh -x "${SYSTEM_TESTS}" -w "${SYSTEST_ROOT}" -V "${VENV_PATH}" -i "${ISO_PATH}" -t test -e "${ENV_NAME}" -o --group=${TEST_GROUP}
