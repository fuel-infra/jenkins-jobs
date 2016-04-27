#!/bin/bash
set -ex

VENV="${WORKSPACE}_VENV"

virtualenv "${VENV}"
source "${VENV}"/bin/activate

pip install -r requirements.txt

python gerrit_notifier.py -c "${GERRIT_NOTIFIER_CONFIG_PATH}"
