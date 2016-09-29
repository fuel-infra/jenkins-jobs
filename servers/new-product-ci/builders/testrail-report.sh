#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER="${TESTRAIL_USER}"
export TESTRAIL_PASSWORD="${TESTRAIL_PASSWORD}"
export TESTRAIL_REPORTER_PATH="${TESTRAIL_REPORTER_PATH:-"fuelweb_test/testrail/report.py"}"
export TESTRAIL_PROJECT="${TESTRAIL_PROJECT:-"Mirantis OpenStack"}"
export TESTRAIL_URL="https://mirantis.testrail.com"

# Prepare venv
source "${VENV_PATH}/bin/activate"
export PYTHONPATH="$(pwd):$PYTHONPATH"

RUNNER_BUILD_NUMBER=$(curl "${JENKINS_URL}/job/${TESTS_RUNNER}/lastBuild/buildNumber")

if [ "${BUG_STATISTIC}" == "true" ]; then
 OPTIONS="-s -N ${RUNNER_BUILD_NUMBER}"
elif [ "${TEST_JOB_NAME}" != "none" ]; then
 OPTIONS="-o ${TEST_JOB_NAME}"
fi

# export test run for testrail
export TESTRAIL_DESCRIPTION="${JENKINS_URL}/job/${TESTS_RUNNER}/${RUNNER_BUILD_NUMBER}"

# Report tests results from swarm (Ubuntu)

export USE_UBUNTU=true
export USE_CENTOS=false
# shellcheck disable=SC2086
python ${TESTRAIL_REPORTER_PATH} -v -l -j "${TESTS_RUNNER}" ${OPTIONS}
