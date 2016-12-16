#!/bin/bash
#
#   :mod: `build-mcp-docs.sh` -- this script builds Mirantis Cloud Platform
#        documentation and publishes it to ``http://docs.mirantis.com``
#   =========================================================================
#
#   .. module:: build-mcp-docs.sh
#       :platform: Unix
#       :synopsys: this script creates Mirantis Cloud Platform documentation
#                  in mcp/mcp-docs repository and publishes it to
#                  docs.mirantis.com
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var GERRIT_BRANCH: Fuel QA internal branch
#       :var DOCS_HOST: credentials used for publishing, default to
#                       ``docs@docs.fuel-infra.org``
#       :var DOCS_ROOT: path to documentation directory (on a target node)
#
#   .. requirements::
#       * valid configuration YAML file: build-mos-docs.yaml
#
#   .. seealso::
#
#   .. warnings::

set -ex

echo "Description string: ${GERRIT_BRANCH}"

VENV="${WORKSPACE}_VENV"

virtualenv "${VENV}"
source "${VENV}/bin/activate" || exit 1

  pip install tox
  tox -e publishdocs

deactivate

# Publishing
# DOCS_HOST and DOCS_ROOT variables are injected
# shellcheck disable=SC2029
ssh "${DOCS_HOST}" "mkdir -p ${DOCS_ROOT}"

BRANCH_ID="${GERRIT_BRANCH##*/}"

DOCS_PATH="${DOCS_HOST}:${DOCS_ROOT}/${BRANCH_ID}"

  rsync -rv publish-docs/ "${DOCS_PATH}"
