#!/bin/bash

set -ex

export TESTRAIL_USER="${TESTRAIL_USER}"
export TESTRAIL_PASSWORD="${TESTRAIL_PASSWORD}"
export TESTRAIL_REPORTER_PATH="${TESTRAIL_REPORTER_PATH:-"fuelweb_test/testrail/report.py"}"
export TESTRAIL_PROJECT="${TESTRAIL_PROJECT:-"Mirantis OpenStack"}"
export TESTRAIL_URL="https://mirantis.testrail.com"

# Prepare venv
source "${VENV_PATH}/bin/activate"
export PYTHONPATH="$(pwd):$PYTHONPATH"

if [[ "${RUNNER_BUILD_NUMBER}" == "latest" ]]; then
    RUNNER_BUILD_NUMBER=$(curl "${JENKINS_URL}/job/${TESTS_RUNNER}/lastBuild/buildNumber")
fi

# export test run for testrail
if [[ ! -n "${TESTRAIL_DESCRIPTION}" ]]; then
    export TESTRAIL_DESCRIPTION="${JENKINS_URL}/job/${TESTS_RUNNER}/${RUNNER_BUILD_NUMBER}"
fi

python "${TESTRAIL_REPORTER_PATH}" -v -j "${TESTS_RUNNER}" -N "${RUNNER_BUILD_NUMBER}"
