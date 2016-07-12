#!/bin/bash

set -ex

# Building

echo "Description string: $GERRIT_BRANCH"

VENV="${WORKSPACE}_VENV"
virtualenv "${VENV}"
source "${VENV}/bin/activate" || exit 1

pip install -r "${WORKSPACE}/fuelweb_test/requirements-devops-source.txt"
pip install -r "${WORKSPACE}/fuelweb_test/requirements.txt"
pip install -r "${WORKSPACE}/doc/requirements.txt"

(cd doc/ && make clean-doc doc-html)

deactivate

# Publishing

DOCS_HOST='docs@docs.fuel-infra.org'
DOCS_ROOT='/var/www/fuel-qa'
# shellcheck disable=SC2029
ssh "${DOCS_HOST}" "mkdir -p ${DOCS_ROOT}"

BRANCH_ID=${GERRIT_BRANCH//\//_}

DOCS_PATH="${DOCS_HOST}:${DOCS_ROOT}/fuel-${BRANCH_ID}"

rsync -rv --delete --exclude pdf/ doc/_build/html/ "${DOCS_PATH}"
