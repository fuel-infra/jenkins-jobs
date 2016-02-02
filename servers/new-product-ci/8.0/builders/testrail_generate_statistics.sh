#!/bin/bash

set -ex

# Prepare venv
source "${VENV_PATH:-/home/jenkins/venv-nailgun-tests-2.9/bin/activate}"

# Initialize variables
export TESTRAIL_STATS_GENERATOR="fuelweb_test/testrail/generate_statistics.py"

OPTIONS=" --verbose"

if [ "${HANDLE_BLOCKED}" == "true" ]; then
    OPTIONS+=" --handle-blocked"
fi

if [ "${PUBLISH}" == "true" ]; then
    OPTIONS+=" --publish"
fi

if [ "${OUTPUT_FILE:-none}" != "none" ]; then
    OPTIONS+=" --out-file ${OUTPUT_FILE}"
fi

if [ "${TESTRAIL_RUN_IDS:-none}" != "none" ]; then
    OPTIONS+=" --run-id ${TESTRAIL_RUN_IDS}"
fi

if [ "${TEST_RUNNER_JOB_NAME:-none}" != "none" ]; then
    OPTIONS+=" --job-name ${TEST_RUNNER_JOB_NAME}"
fi

if [ "${TEST_RUNNER_BUILD_NUMBER:-none}" != "none" ]; then
    OPTIONS+=" --build-number ${TEST_RUNNER_BUILD_NUMBER}"
fi

if [ "${SEPARATE_RUNS}" == "true" ]; then
    OPTIONS+=" --separate-runs"
fi

if [ "${CREATE_HTML}" == "true" ]; then
    OPTIONS+=" --html"
fi

if [ "${TEST_PLAN_ID:-none}" != "none" ]; then
    OPTIONS+=" ${TEST_PLAN_ID}"
fi

python "${TESTRAIL_STATS_GENERATOR}" ${OPTIONS}
