#!/bin/bash

set -ex

export TEST_WORKERS=4

VENV=${WORKSPACE}_VENV
virtualenv -p python2.6 ${VENV}
source ${VENV}/bin/activate

export TEST_NAILGUN_DB=nailgun

cd $WORKSPACE
./run_tests.sh --with-xunit --no-webui

deactivate
