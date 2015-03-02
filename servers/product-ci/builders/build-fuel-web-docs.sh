#!/bin/bash

set -ex

#Building

VENV=${WORKSPACE}_VENV
mkdir -p $VENV
virtualenv --system-site-packages $VENV
source $VENV/bin/activate

pip install ./shotgun
pip install -r nailgun/test-requirements.txt

cd docs/
make clean html pdf
ls
deactivate

# Publishing

DOCS_HOST='docs@docs.fuel-infra.org'
DOCS_ROOT='/var/www/fuel-dev-docs'
ssh ${DOCS_HOST} "mkdir -p ${DOCS_ROOT}"

BRANCH_ID=$(echo ${GERRIT_BRANCH##*/} | sed 's:/:_:g')

ssh ${DOCS_HOST} "mkdir -p ${DOCS_ROOT}"
DOCS_PATH=${DOCS_HOST}:${DOCS_ROOT}/fuel-dev-${BRANCH_ID}

rsync -rv --delete _build/html/ $DOCS_PATH
rsync -rv --delete _build/pdf/ $DOCS_PATH/pdf/
