#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}
export TESTRAIL_REPORTER_PATH="fuelweb_test/testrail/report.py"

# Prepare venv
source /home/jenkins/qa-venv-7.0/bin/activate

# export test run for testrail
RUNNER_BUILD_NUMBER=$(curl "${JENKINS_URL}/job/${TESTS_RUNNER}/lastBuild/buildNumber")
export TESTRAIL_DESCRIPTION="${JENKINS_URL}/job/${TESTS_RUNNER}/${RUNNER_BUILD_NUMBER}"

# Report tests results from swarm (Ubuntu)

export USE_UBUNTU=true
export USE_CENTOS=false
# shellcheck disable=SC2086
python ${TESTRAIL_REPORTER_PATH} -v -l -j ${TESTS_RUNNER} ${OPTIONS}
