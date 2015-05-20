#!/bin/bash

set -ex

rm -rf "${VENV_PATH}"

virtualenv --system-site-packages "${VENV_PATH}"
source "${VENV_PATH}/bin/activate"
pip install -r "${REQS_PATH}" --upgrade
django-admin.py syncdb --settings=devops.settings --noinput
django-admin.py migrate devops --settings=devops.settings --noinput
deactivate
