#!/bin/bash

set -ex

echo "Description string: ${GERRIT_BRANCH}"

export SOURCEDIR="${WORKSPACE}/doc/source"
export BUILDDIR="${WORKSPACE}/_build/html"
export VENV="${WORKSPACE}_VENV"

virtualenv "${VENV}"
source "${VENV}/bin/activate"

pip install -r requirements.txt

mkdir -p ${BUILDDIR}
# Producing htmls
sphinx-build -b html "${SOURCEDIR}" "${BUILDDIR}"

deactivate

# Publishing
DOCS_HOST="docs@docs.fuel-infra.org"
DOCS_ROOT="/var/www/specs"

BRANCH_ID=$(echo "${GERRIT_BRANCH##*/}" | sed 's:/:_:g')

DOCS_PATH="${DOCS_HOST}:${DOCS_ROOT}/fuel-specs-${BRANCH_ID}"

rsync -rv --delete "${WORKSPACE}/_build/html/" "${DOCS_PATH}"
