#!/bin/bash

set -ex

VENV="${WORKSPACE}_VENV"

virtualenv --clear "${VENV}"
source "${VENV}/bin/activate"

pip install tox

tox -e publishdocs

deactivate
