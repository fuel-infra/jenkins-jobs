#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}

# Prepare venv
source /home/jenkins/venv-nailgun-tests-2.9/bin/activate

export PYTHONPATH="$(pwd):$PYTHONPATH"

python fuelweb_test/testrail/upload_cases_description.py -v -j ${TESTS_RUNNER}
