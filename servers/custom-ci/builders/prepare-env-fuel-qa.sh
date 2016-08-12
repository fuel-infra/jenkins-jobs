#!/bin/bash

set -ex

# Run prepare environment script from test framework repository
if [ "$TEST_FRAMEWORK_URL" != "https://github.com/openstack/fuel-qa.git" ] ; then
    # Redefine path to venv if use non standart test framework
    VENV_PATH="${WORKSPACE}/venv_test"
    export VENV_PATH="${VENV_PATH}"
    # Parameter used for prepare environment script
    export FUELQA_GITREF="${FUEL_QA_COMMIT}"
    # Run script for preparing environment from fuel-plugin-murano-tests and stacklight-integration-tests
    if [ -f ./utils/fuel-qa-builder/prepare_env.sh ] ; then
        ./utils/fuel-qa-builder/prepare_env.sh
    fi
fi
