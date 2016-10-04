#!/bin/bash

set -ex

source "${VENV_PATH}/bin/activate"

if [ -z "${TESTRAIL_TEST_SUITE}" -o -z "${TESTRAIL_URL}" ]; then
  echo 1>&2 'ERROR! Some TestRail parameters are not set, default values will be used!'
  exit 1
fi

if [ -n "${MANUAL}" ]; then
  OPTIONS=" --manual"
fi

python fuelweb_test/testrail/report.py --verbose ${OPTIONS} --job-name "${TESTS_RUNNER}" --build-number "${BUILD_NUMBER}"
