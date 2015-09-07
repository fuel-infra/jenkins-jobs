#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}
export TESTRAIL_REPORTER_PATH="fuelweb_test/testrail/report.py"
export SWARM_RUNNER_JOB_NAME='8.0.swarm.runner'

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate

if [ "${TEST_JOB_NAME_ENABLE}" == "true" ]; then
 TEST_JOB_NAME=$(curl "${JENKINS_URL}/job/${JOB_NAME}/${BUILD_NUMBER}/api/json?tree=actions\[causes\[upstreamProject\]\]&pretty=true" |grep upstreamProject |cut -d'"' -f4)
fi

if [ "${BUG_STATISTIC}" == "true" ]; then
 RUNNER_BUILD_NUMBER=$(curl "${JENKINS_URL}/job/${SWARM_RUNNER_JOB_NAME}/lastBuild/buildNumber")
 OPTIONS="-s -N ${RUNNER_BUILD_NUMBER}"
elif [ "${TEST_JOB_NAME}" != "" ]; then
 OPTIONS="-o ${TEST_JOB_NAME}"
fi

# Report tests results from swarm (Ubuntu)

export TESTRAIL_TEST_SUITE='Swarm 8.0'
export USE_UBUNTU=true
export USE_CENTOS=false
python ${TESTRAIL_REPORTER_PATH} -v -l -j "${SWARM_RUNNER_JOB_NAME}" ${OPTIONS}

# Report tests results from swarm (CentOS)

export TESTRAIL_TEST_SUITE="Upgrade Centos Cluster"
export USE_UBUNTU=false
export USE_CENTOS=true
python ${TESTRAIL_REPORTER_PATH} -v -l -j "${SWARM_RUNNER_JOB_NAME}" ${OPTIONS}
