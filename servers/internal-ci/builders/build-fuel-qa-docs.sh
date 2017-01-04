#!/bin/bash
#
#   :mod: `build-fuel-qa-docs.sh` -- this script builds Fuel QA documentation
#        for active branches and publishes it to ``http://docs.mirantis.com``
#   =========================================================================
#
#   .. module:: build-fuel-qa-docs.sh
#       :platform: Unix
#       :synopsys: this script creates Fuel QA documentation for all active
#                  active branches and publishes it to dosc.mirantis.com
#   .. versionadded:: MOS-8.0
#   .. versionchanged:: MOS-9.0
#   .. author:: Lesya Novaselskaya <onovaselskaya@mirantis.com>
#
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var VENV: build specific virtual environment path (deployed)
#       :var BRANCH_ID: Fuel QA build branch (deployed)
#       :var GIT_BRANCH: Fuel QA external official branch
#       :var DOCS_HOST: credentials used for publishing, default to
#                       ``docs@docs.fuel-infra.org`` (deployed)
#       :var DOCS_ROOT: path to documentation directory (deployed)
#
#   .. requirements::
#       * valid configuration YAML file: build-fuel-qa-docs.yaml
#
#   .. seealso::
#
#   .. warnings::

set -ex

# Building

echo "Description string: ${GIT_BRANCH}"

VENV="${WORKSPACE}_VENV"

if [ ! -d "${VENV}" ]; then
  virtualenv "${VENV}"
fi

source "${VENV}/bin/activate" || exit 1

pip install -r "${WORKSPACE}/fuelweb_test/requirements.txt"
pip install -r "${WORKSPACE}/doc/requirements.txt"

(cd doc/ && make clean-doc doc-html)

deactivate

# Publishing
# DOCS_HOST and DOCS_ROOT variables are injected
# shellcheck disable=SC2029
ssh "${DOCS_HOST}" "mkdir -p ${DOCS_ROOT}"

BRANCH_ID="${GIT_BRANCH##*/}"

DOCS_PATH="${DOCS_HOST}:${DOCS_ROOT}/fuel-${BRANCH_ID}"

rsync -rv --delete --exclude pdf/ doc/_build/html/ "${DOCS_PATH}"
