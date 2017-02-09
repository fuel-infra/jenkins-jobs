#!/bin/bash

set -ex

RUNNER_SCRIPT=${RUNNER_SCRIPT:-utils/jenkins/fuel_noop_tests.sh}

source /etc/profile
/bin/bash "${WORKSPACE}/${RUNNER_SCRIPT}"
