#!/bin/bash

set -ex

if [ "${UPDATE_VENV}" != "true" ];
then
  exit 0
fi

rm -rf "${VENV_PATH}"

REQS_PATH="${WORKSPACE}/fuel-qa/fuelweb_test/requirements.txt"

virtualenv --system-site-packages "${VENV_PATH}"
source "${VENV_PATH}/bin/activate"
pip install -r "${REQS_PATH}" --upgrade
django-admin.py syncdb --settings=devops.settings --noinput
django-admin.py migrate devops --settings=devops.settings --noinput
deactivate
