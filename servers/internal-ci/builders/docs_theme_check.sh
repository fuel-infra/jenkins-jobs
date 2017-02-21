#!/bin/bash
#
#   :mod: `docs_theme_check.sh` -- this script builds
#      Mirantis documentation with mirantisdocstheme changes
#   =========================================================================
#
#   .. module:: docs_theme_check.sh
#       :platform: Unix
#       :synopsys: this script creates Mirantis documentation from master branch
#                  with changes for docs/mirantisdocstheme
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#
#   .. requirements::
#       * valid configuration YAML file: docs_theme_check.yaml
#
#   .. seealso::
#
#   .. warnings::

set -ex

VENV="${WORKSPACE}_VENV"

[[ ! -d "${VENV}" ]] && virtualenv "${VENV}"

source "${VENV}/bin/activate" || exit 1

  pip install tox
  tox -e publishdocs

deactivate
