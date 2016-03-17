#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}
export TESTRAIL_REPORTER_PATH="fuelweb_test/testrail/report.py"
export SWARM_RUNNER_JOB_NAME='9.0.swarm.runner'

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
export PYTHONPATH="$(pwd):$PYTHONPATH"

if [ "${BUG_STATISTIC}" == "true" ]; then
 RUNNER_BUILD_NUMBER=$(curl "${JENKINS_URL}/job/${SWARM_RUNNER_JOB_NAME}/lastBuild/buildNumber")
 OPTIONS="-s -N ${RUNNER_BUILD_NUMBER}"
elif [ "${TEST_JOB_NAME}" != "none" ]; then
 OPTIONS="-o ${TEST_JOB_NAME}"
fi

# Report tests results from swarm (Ubuntu)

export TESTRAIL_TEST_SUITE='[9.0] Swarm'
export USE_UBUNTU=true
export USE_CENTOS=false
python ${TESTRAIL_REPORTER_PATH} -v -l -j "${SWARM_RUNNER_JOB_NAME}" ${OPTIONS}

