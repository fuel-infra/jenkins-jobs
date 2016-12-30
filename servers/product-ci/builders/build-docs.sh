#!/bin/bash
#
#   :mod: `build-docs.sh` -- this script builds documentation for
#        9.1 and never branches Mirantis OpenStack documentation and
#        Mirantis Cloud Platform documentations and publishes it to
#        ``http://docs.mirantis.com``
#   =========================================================================
#
#   .. module:: build-docs.sh
#       :platform: Unix
#       :synopsys: this script creates MOS and MCP documentation in mos/mos-docs
#                  and mcp/mcp-docs repository and publishes it to
#                  docs.mirantis.com
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var GERRIT_BRANCH: Fuel QA internal branch
#       :var DOCS_USER: username used for publishing, for example ``docs``
#       :var DOCS_HOST: host used for publishing, for example
#                       ``docs.fuel-infra.org``
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
# DOCS_HOST DOCS_ROOT and DOCS_USER variables are injected
# shellcheck disable=SC2029
ssh "${DOCS_USER}@${DOCS_HOST}" "mkdir -p ${DOCS_ROOT}"

BRANCH_ID="${GERRIT_BRANCH##*/}"

DOCS_PATH="${DOCS_USER}@${DOCS_HOST}:${DOCS_ROOT}${BRANCH_ID}"

  rsync -rv publish-docs/ "${DOCS_PATH}"
