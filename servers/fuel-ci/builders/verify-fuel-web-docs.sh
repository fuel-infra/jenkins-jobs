#!/bin/bash

set -ex

echo "INFO: Job has been updated to use virtualenv"

VENV=${WORKSPACE}_VENV

virtualenv ${VENV}
source ${VENV}/bin/activate

cd ${WORKSPACE}
pip install shotgun/

cd ${WORKSPACE}/nailgun
pip install -r test-requirements.txt

ln -s /usr/share/plantuml/plantuml.jar ${WORKSPACE}/docs/plantuml.jar

# Actual work
cd ${WORKSPACE}/docs
make clean html
