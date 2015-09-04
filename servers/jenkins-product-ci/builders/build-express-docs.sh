#!/bin/bash

set -ex

echo "Description string: $GIT_BRANCH"

VENV="${WORKSPACE}_VENV"

virtualenv "${VENV}"
source "${VENV}/bin/activate" || exit 1

pip install -r requirements.txt

make clean html pdf
cp uploads/* _build/pdf/

deactivate

# Publishing

DOCS_HOST='docs@docs.fuel-infra.org'
DOCS_ROOT='/var/www/openstack/express'
ssh ${DOCS_HOST} "mkdir -p ${DOCS_ROOT}"

BRANCH_ID=$(echo ${GIT_BRANCH##*/} | sed 's:/:_:g')

DOCS_PATH=${DOCS_HOST}:${DOCS_ROOT}/${BRANCH_ID}

rsync -rv --delete _build/html/ $DOCS_PATH
rsync -rv --delete _build/pdf/ $DOCS_PATH/pdf/
