#!/bin/bash
#
#   :mod: `build-mos-glossary.sh` -- this script  builds MOS Glossary
#        for active branches and publishes it to ``http://docs.mirantis.com``
#   =========================================================================
#
#   .. module:: build-mos-glossary.sh
#       :platform: Unix
#       :synopsys: this script creates MOS Glossary for a branch
#                  in mos/glossary repository and publishes it to
#                  docs.mirantis.com
#   .. versionadded:: MOS-9.1
#   .. author:: Sergey Otpuschennikov <sotpuschennikov@mirantis.com>
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var GERRIT_BRANCH: mos/glossary internal branch
#       :var DOCS_USER: credentials used for publishing, default to
#                       ``docs``
#       :var DOCS_HOST: host used for publishing, default to
#                       ``docs.fuel-infra.org``
#       :var DOCS_ROOT: path to documentation directory (on a target node)
#
#   .. requirements::
#       * valid configuration YAML file: build-mos-glossary.yaml
#
#   .. seealso::
#
#   .. warnings::

set -ex

echo "Description string: ${GERRIT_BRANCH}"

VENV="${WORKSPACE}_VENV"

virtualenv "${VENV}"
source "${VENV}/bin/activate"

    pip install tox
    tox -e docs

deactivate

# Publishing
# DOCS_USER, DOCS_HOST and DOCS_ROOT variables are injected
# shellcheck disable=SC2029
ssh "${DOCS_USER}@${DOCS_HOST}" "mkdir -p ${DOCS_ROOT}"

DOCS_PATH="${DOCS_USER}@${DOCS_HOST}:${DOCS_ROOT}/glossary/"

    rsync -rv build-docs/mos-glossary/ "${DOCS_PATH}"
    rsync -rv build-docs/mcp-glossary/ "${DOCS_PATH}mcp/"
