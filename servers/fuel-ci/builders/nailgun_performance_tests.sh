#!/bin/bash

set -x
set -e

VENV="${WORKSPACE}_VENV"
virtualenv -p python2.6 "${VENV}"
source ${VENV}/bin/activate

export TEST_NAILGUN_DB="nailgun"

cd $WORKSPACE/nailgun/nailgun

sed -i 's#PERFORMANCE_PROFILING_TESTS:.*#PERFORMANCE_PROFILING_TESTS: 1#' settings.yaml
sed -i 's#load_tests_base:.*#load_tests_base: "'${WORKSPACE}'/results/tests/"#' settings.yaml
sed -i 's#last_performance_test:.*#last_performance_test: "'${WORKSPACE}'/results/last/"#' settings.yaml
sed -i 's#load_tests_results:.*#load_tests_results: "'${WORKSPACE}'/results/results/"#' settings.yaml

nosetests test/performance
