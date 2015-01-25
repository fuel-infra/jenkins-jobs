#!/bin/bash

set -ex

export TEST_NAILGUN_DB="nailgun"

export PATH=${PATH}:${NPM_CONFIG_PREFIX}/bin

VENV="${WORKSPACE}_VENV"
NODE_MODULES=${VENV}/node_modules

virtualenv -p python2.6 "${VENV}"
source ${VENV}/bin/activate

python --version

cd ${WORKSPACE}
pip install shotgun

cd ${WORKSPACE}/nailgun

pip install -r test-requirements.txt ${PIP_OPTION}

mkdir -p ${NODE_MODULES}
ln -s ${NODE_MODULES} node_modules

# Fix of failure of NPM
for i in `seq 1 2`; do
  npm install && break
done

cd ${WORKSPACE}

if [ -f ./fuel_upgrade_system/fuel_upgrade/requirements.txt ]; then
  pip install -r fuel_upgrade_system/fuel_upgrade/requirements.txt
fi

if [ -f ./fuel_upgrade_system/fuel_upgrade/test-requirements.txt ]; then
  pip install -r fuel_upgrade_system/fuel_upgrade/test-requirements.txt
fi

flake8 --version

if [ -x ./run_tests.sh ]; then
  ./run_tests.sh --with-xunit
elif [ -x ${WORKSPACE}/nailgun/run_tests.sh ]; then
  cd ${WORKSPACE}/nailgun && ./run_tests.sh --with-xunit
else
  false
fi

deactivate
