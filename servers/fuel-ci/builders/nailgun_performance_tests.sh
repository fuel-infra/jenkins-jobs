#!/bin/bash

set -ex

VENV="${WORKSPACE}_VENV"
virtualenv -p python2.6 "${VENV}"
source ${VENV}/bin/activate

export TEST_NAILGUN_DB="nailgun"

cd ${WORKSPACE}/nailgun/nailgun

# modify paths since by default /tmp/ is used
sed -i 's#load_tests_base:.*#load_tests_base: "'${WORKSPACE}'/results/tests/"#' settings.yaml
sed -i 's#last_performance_test:.*#last_performance_test: "'${WORKSPACE}'/results/last/"#' settings.yaml
sed -i 's#load_tests_results:.*#load_tests_results: "'${WORKSPACE}'/results/results/"#' settings.yaml
sed -i 's#last_performance_test_run:.*#last_performance_test_run: "'${WORKSPACE}'/results/last/run/"#' settings.yaml
sed -i 's#load_previous_tests_results:.*#load_previous_tests_results: "'${WORKSPACE}'/results/previous_results.json"#' settings.yaml

cd ${WORKSPACE}/
mkdir -p ${WORKSPACE}/results
./run_tests.sh -x
