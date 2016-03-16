#!/bin/bash

set -ex

export DISPLAY=:99
export PATH="$PATH:${NPM_CONFIG_PREFIX}/bin"

VENV="${WORKSPACE}_VENV"
[ "${VENV_CLEANUP}" == "true" ] && rm -rf "${VENV}"
virtualenv -p python2.7 "${VENV}"
source "${VENV}/bin/activate"
pip install --upgrade 'tox>=2.3.1'

NODE_MODULES="${VENV}/node_modules"

pushd "${WORKSPACE}"/fuel-ui
mkdir -p "${NODE_MODULES}"

[ -L node_modules ] || ln -s "${NODE_MODULES}" node_modules

npm install
export ARTS="${WORKSPACE}"/artifacts
export ARTIFACTS="${ARTS}"
export FUEL_WEB_ROOT="${WORKSPACE}/fuel-web"
export NAILGUN_DB_HOST=127.0.0.1
export DB_ROOTPW=insecurepassword

# Run UI tests
npm run "${UI_TEST_GROUP}"
popd
deactivate
