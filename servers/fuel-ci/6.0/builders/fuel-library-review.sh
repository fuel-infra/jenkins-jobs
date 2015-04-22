#!/bin/bash

set -ex

if echo "${GERRIT_CHANGE_COMMIT_MESSAGE}" | grep -q -iE "Fuel-CI:\s+disable"; then
  echo "Fuel CI check disabled"
  exit -1
fi

#common params

export LOGS_DIR=/home/jenkins/workspace/${JOB_NAME}/logs/${BUILD_NUMBER}
export UPLOAD_MANIFESTS=true
export UPLOAD_MANIFESTS_PATH=/home/jenkins/workspace/${JOB_NAME}/deployment/puppet/

BRANCH_ID=`echo ${BRANCH##*/} | sed 's:\.:_:g'`

export WORKSPACE="/home/jenkins/workspace/fuel-main/env_${DISTRIBUTION}-${BRANCH_ID}"
export SYSTEM_TESTS="${WORKSPACE}/utils/jenkins/system_tests.sh"
export ENV_NAME="env_${DISTRIBUTION}-${BRANCH_ID}"
export ISO_PATH="/home/jenkins/workspace/iso/fuel_${BRANCH_ID}.iso"

VERSION_STRING=`readlink ${ISO_PATH} | cut -d '-' -f 2-3`
echo "Description string: ${VERSION_STRING}"

sh -x "${SYSTEM_TESTS}" -V "${VENV_PATH}" -i "${ISO_PATH}" -t test -e "${ENV_NAME}" -k -o --group=${TEST_GROUP}
