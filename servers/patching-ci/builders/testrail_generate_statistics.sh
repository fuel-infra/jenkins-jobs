#!/bin/bash

set -ex

# Prepare venv
source "${VENV_PATH:-/home/jenkins/qa-venv-9.x/bin/activate}"

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

# Quoted OPTIONS below WILL NOT WORK; this file is not used anymore
# so this is just for shell check. FIX THIS if one day we will need testrail statistic
python "${TESTRAIL_STATS_GENERATOR}" "${OPTIONS}"
