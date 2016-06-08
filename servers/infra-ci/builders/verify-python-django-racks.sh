#!/bin/bash

set -e
set -x

# required more recent version of tox because of no complex factor conditions in
# tox-1.6.
VENV="${WORKSPACE}_VENV"
virtualenv "${VENV}"
source "${VENV}/bin/activate"
pip install tox
cd racks

tox -v
