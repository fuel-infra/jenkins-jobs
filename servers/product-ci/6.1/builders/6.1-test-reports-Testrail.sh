#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate
export SwarmRunnerName='6.1.swarm.runner'
export Smoke_BVT='6.1.all'
export TestrailCMDPath="fuel-qa/fuelweb_test/testrail/report.py"

# TEPMORARY(START)
# Report tests results from Smoke/BVT
ISO_NUMBER=$(curl -s "${JENKINS_URL}job/${SwarmRunnerName}/lastBuild/api/xml?xpath=/multiJobBuild/action/parameter&wrapper=name" | sed -rn 's/.*\bfuel-[0-9](\.[0-9])*-([0-9]+)-[0-9]+.*/\2/p')
export TESTRAIL_TEST_SUITE='Smoke/BVT'
python ${TestrailCMDPath} -m -v -j "${Smoke_BVT}" -N "${ISO_NUMBER}"
# TEPMORARY(END)

# Report tests results from swarm

export TESTRAIL_TEST_SUITE='Swarm 6.1'
export TESTRAIL_TEST_subSUITE='6.1.swarm.runner'

python ${TestrailCMDPath} -v -l -j "${TESTRAIL_TEST_subSUITE}"
