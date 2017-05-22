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

{
    echo "# Requirements for ${VIRTUAL_ENV} ${BRANCH}"
    curl -fsS "https://raw.githubusercontent.com/openstack/fuel-qa/${BRANCH}/fuelweb_test/requirements.txt"
    curl -fsS "https://raw.githubusercontent.com/openstack/fuel-qa/${BRANCH}/fuelweb_test/requirements-devops-source.txt"
    echo "${ADDITIONAL_REQUIREMENTS}"
} > requirements.txt

echo "===> Generated requirements list:"
cat requirements.txt

echo "===> Installing/updating packages"
pip install -U pip
pip install -U -r requirements.txt

rm requirements.txt
echo "===> Installed packages:"
pip freeze

echo "===> Configuring devops"
django-admin.py syncdb --settings=devops.settings --noinput
django-admin.py migrate devops --settings=devops.settings --noinput

deactivate

