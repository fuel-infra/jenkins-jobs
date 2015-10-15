#!/bin/bash

set -ex

# Cherry-pick upper bounds for test requirements
# https://bugs.launchpad.net/fuel/+bug/1473926

git fetch https://review.openstack.org/openstack/fuel-web refs/changes/30/201030/2 && git cherry-pick FETCH_HEAD

export TEST_WORKERS=4
export PATH=$PATH:$NPM_CONFIG_PREFIX/bin

VENV=${WORKSPACE}_VENV
virtualenv -p python2.6 ${VENV}
source ${VENV}/bin/activate

NODE_MODULES=${VENV}/node_modules

cd $WORKSPACE/nailgun
mkdir -p ${NODE_MODULES}
ln -s ${NODE_MODULES} node_modules
npm install

export TEST_NAILGUN_DB=nailgun

cd $WORKSPACE
./run_tests.sh --with-xunit

deactivate
