#!/bin/bash

set -ex

export TEST_WORKERS=4
export PATH=$PATH:$NPM_CONFIG_PREFIX/bin

VENV=${WORKSPACE}_VENV
virtualenv -p python2.6 "${VENV}"
source "${VENV}/bin/activate"

# Workaround for https://github.com/kennethreitz/requests/issues/3670
pip install --upgrade requests

# Upgrade too old core packages which can't be upgrade with requirements file
pip install -U pip
pip install -U setuptools

NODE_MODULES=${VENV}/node_modules

cd "$WORKSPACE/nailgun"
mkdir -p "${NODE_MODULES}"
ln -s "${NODE_MODULES}" node_modules
npm install

export TEST_NAILGUN_DB=nailgun

cd "$WORKSPACE"
./run_tests.sh --with-xunit

deactivate
