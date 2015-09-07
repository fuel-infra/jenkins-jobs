#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
export SwarmRunnerName='8.0.swarm.runner'
export Smoke_BVT='8.0.all'
export TestrailCMDPath="fuelweb_test/testrail/report.py"

# Report tests results from swarm
#export TESTRAIL_TEST_SUITE='Swarm 8.0'
#export TESTRAIL_TEST_subSUITE='8.0.swarm.runner'

python ${TestrailCMDPath} -v -l -j "${Smoke_BVT}" -c
