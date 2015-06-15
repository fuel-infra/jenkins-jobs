#!/bin/bash

set -ex

#common params

export MIRROR_UBUNTU="$(curl -sSf "${JENKINS_URL}job/devops.master.env/lastSuccessfulBuild/artifact/mirror_ubuntu_data.txt")"


export LOGS_DIR="/home/jenkins/workspace/${JOB_NAME}/logs/${BUILD_NUMBER}"
export UPDATE_FUEL=true
export UPDATE_FUEL_PATH="${WORKSPACE}/packages/"
export UBUNTU_RELEASE='auxiliary'
export LOCAL_MIRROR_UBUNTU='/var/www/nailgun/ubuntu/auxiliary/'
export LOCAL_MIRROR_CENTOS='/var/www/nailgun/centos/auxiliary/'
export EXTRA_RPM_REPOS_PRIORITY=15
export EXTRA_DEB_REPOS_PRIORITY=1100

BRANCH_ID=${BRANCH##*/}
BRANCH_ID=${BRANCH_ID//./_}

export WORKSPACE="/home/jenkins/workspace/fuel-main/env_${DISTRIBUTION}-${BRANCH_ID}"
export SYSTEM_TESTS="${WORKSPACE}/utils/jenkins/system_tests.sh"
export ENV_NAME="env_${DISTRIBUTION}-${BRANCH_ID}"
export ISO_PATH="/home/jenkins/workspace/iso/fuel_${BRANCH_ID}.iso"

VERSION_STRING=$(readlink "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: ${VERSION_STRING}"

sh -x "${SYSTEM_TESTS}" -V "${VENV_PATH}" -i "${ISO_PATH}" -t test -e "${ENV_NAME}" -k -o --group="${TEST_GROUP}"
