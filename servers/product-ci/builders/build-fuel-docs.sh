#!/bin/bash

set -ex

echo "Description string: $GERRIT_BRANCH"

make clean html pdf

# Publishing

DOCS_HOST='docs@docs.fuel-infra.org'
DOCS_ROOT='/var/www/openstack/fuel'
ssh ${DOCS_HOST} "mkdir -p ${DOCS_ROOT}"

BRANCH_ID=$(echo ${GERRIT_BRANCH##*/} | sed 's:/:_:g')

DOCS_PATH=${DOCS_HOST}:${DOCS_ROOT}/fuel-${BRANCH_ID}

rsync -rv --delete --exclude pdf/ _build/html/ ${DOCS_PATH}
rsync -rv _build/pdf/ ${DOCS_PATH}/pdf/

