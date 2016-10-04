#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
export SwarmRunnerName='9.0-kilo.swarm.runner'
export Smoke_BVT='9.0-kilo.all'
export TestrailCMDPath="fuelweb_test/testrail/report.py"

# Report tests results from swarm
#export TESTRAIL_TEST_SUITE='[9.0-kilo] Swarm'
#export TESTRAIL_TEST_subSUITE='9.0-kilo.swarm.runner'

python ${TestrailCMDPath} -v -l -j "${Smoke_BVT}" -c
