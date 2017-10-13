#!/bin/bash

set -ex

if [[ -d "${VIRTUAL_ENV}" ]] && [[ "${CLEAN_VIRTUAL_ENV}" == "true" ]]; then
    rm -rf "${VIRTUAL_ENV}"
fi

if [[ ! -f "${VIRTUAL_ENV}/bin/activate" ]]; then
    rm -rf "${VIRTUAL_ENV}"
    virtualenv --no-site-packages "${VIRTUAL_ENV}"
fi

source "${VIRTUAL_ENV}/bin/activate"

if [[ "${ADDITIONAL_REQUIREMENTS}" ]]; then
  echo "===> Using ADDITIONAL_REQUIREMENTS variable"
  echo "${ADDITIONAL_REQUIREMENTS}" > requirements.txt
  pip install -r requirements.txt
  rm requirements.txt
fi
pushd fuel-qa/fuelweb_test
  echo "===> Installing/updating packages"
  pip install -U pip
  pip install -U -r requirements-devops-source.txt -r requirements.txt
popd

echo "===> Installed packages:"
pip freeze

echo "===> Configuring devops"
django-admin.py syncdb --settings=devops.settings --noinput
django-admin.py migrate devops --settings=devops.settings --noinput

deactivate

