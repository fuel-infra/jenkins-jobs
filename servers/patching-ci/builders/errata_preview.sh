#!/bin/bash

set -ex

VENV=${WORKSPACE}_VENV

virtualenv ${VENV}
source ${VENV}/bin/activate

pip install -r /home/jenkins/errata-preview/requirements.txt

mkdir -p html

git diff HEAD~1 --name-only --diff-filter=AM | grep ".yaml$" | xargs --no-run-if-empty /home/jenkins/errata-preview/import.py

echo 'Description string: <a href="${JOB_URL}${BUILD_NUMBER}/Errata_preview/">Errata html preview</a>'
