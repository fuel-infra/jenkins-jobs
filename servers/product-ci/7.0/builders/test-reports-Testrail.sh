#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
export SwarmRunnerName='7.0.swarm.runner'
export Smoke_BVT='7.0.all'
export TestrailCMDPath="fuelweb_test/testrail/report.py"

# Report tests results from swarm

export TESTRAIL_TEST_SUITE='Swarm 7.0'
export TESTRAIL_TEST_subSUITE='7.0.swarm.runner'

if [ "${TEST_JOB_NAME_ENABLE}" == "true" ]; then
 TEST_JOB_NAME=$(curl "${JENKINS_URL}job/7.0.swarm.Testrail/lastBuild/api/json?tree=actions\[causes\[upstreamProject\]\]&pretty=true" |grep upstreamProject |cut -d'"' -f4)
fi

if [ "${BUG_STATISTIC}" == "true" ]; then
 RUNNER_BUILD_NUMBER=$(curl ${JENKINS_URL}view/7.0_swarm/job/7.0.swarm.runner/lastBuild/buildNumber)
 OPTIONS="-s -N ${RUNNER_BUILD_NUMBER}"
elif [ "${TEST_JOB_NAME}" != "" ]; then
 OPTIONS="-o ${TEST_JOB_NAME}"
fi

python ${TestrailCMDPath} -v -l -j "${TESTRAIL_TEST_subSUITE}" ${OPTIONS}
