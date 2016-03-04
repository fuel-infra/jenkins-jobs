#!/bin/bash

set -ex

export DISPLAY=:99
export PATH=$PATH:${NPM_CONFIG_PREFIX}/bin


VENV="${WORKSPACE}_VENV"
[ "${VENV_CLEANUP}" == "true" ] && rm -rf "${VENV}"
virtualenv -p python2.7 "${VENV}"
source "${VENV}/bin/activate"
pip install --upgrade 'tox>=2.3.1'

NODE_MODULES="${VENV}/node_modules"

mkdir -p "${NODE_MODULES}"

pushd "${WORKSPACE}"/fuel-ui
[ -L node_modules ] || ln -s "${NODE_MODULES}" node_modules

npm install
export ARTS="${WORKSPACE}"/test_run/ui_func
export ARTIFACTS="${WORKSPACE}"/test_run/ui_func
export FUEL_WEB_ROOT="${WORKSPACE}"
export NAILGUN_DB_HOST=127.0.0.1
export DB_ROOTPW=insecurepassword

# Run UI tests
npm test
popd
deactivate
