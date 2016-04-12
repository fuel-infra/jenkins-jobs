#!/bin/bash
#
# TestRail

set -ex

export TESTRAIL_USER=${TESTRAIL_USER}
export TESTRAIL_PASSWORD=${TESTRAIL_PASSWORD}
export TESTRAIL_PROJECT="Mirantis OpenStack"
export TESTRAIL_URL="https://mirantis.testrail.com"

# Prepare venv
source "${VENV_PATH}/bin/activate"
export PYTHONPATH="$(pwd):$PYTHONPATH"

python fuelweb_test/testrail/upload_cases_description.py -v -j ${TESTS_RUNNER}
