#!/bin/bash
#
#   :mod: `internal-docs.sh` -- this script builds internal
#        Mirantis  documentation and publishes it to
#        ``http://docs.mirantis.com``
#   =========================================================================
#
#   .. module:: internal-docs.sh
#       :platform: Unix
#       :synopsys: this script creates internal Mirantis documentation in
#                  and docs/internal repository and publishes it to
#                  docs.mirantis.com
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var GERRIT_EVENT_TYPE: type of gerrit event
#       :var DOCS_USER: username used for publishing, for example ``docs``
#       :var DOCS_HOST: host used for publishing, for example
#                       ``docs.fuel-infra.org``
#       :var DOCS_ROOT: path to documentation directory (on a target node)
#
#   .. requirements::
#       * valid configuration YAML file: internal-docs.yaml
#
#   .. seealso::
#
#   .. warnings::

set -ex

VENV="${WORKSPACE}_VENV"
SOURCE_DIR="publish-docs"
LANDING_PAGE_DIR="www/landing_page"
INTERNAL_DOCS_ROOT="${DOCS_ROOT}/internal"

[[ ! -d "${VENV}" ]] && virtualenv "${VENV}"

source "${VENV}/bin/activate" || exit 1

  pip install tox
  tox -e publishdocs

deactivate

if [ -z "${GERRIT_EVENT_TYPE}" -o "${GERRIT_EVENT_TYPE}" == "change-merged" ]; then
    # Publishing after merge
    # DOCS_HOST DOCS_ROOT and DOCS_USER variables are injected
    # shellcheck disable=SC2029
    ssh "${DOCS_USER}@${DOCS_HOST}" "mkdir -p ${INTERNAL_DOCS_ROOT}"

    DOCS_PATH="${DOCS_USER}@${DOCS_HOST}:${INTERNAL_DOCS_ROOT}"
    LANDING_PAGE_PATH="${DOCS_USER}@${DOCS_HOST}:${DOCS_ROOT}"

    rsync -rv --delete "${SOURCE_DIR}/" "${DOCS_PATH}"
    # Upload the landing page docs.mirantis.com
    rsync -rv "${LANDING_PAGE_DIR}/" "${LANDING_PAGE_PATH}"
fi
