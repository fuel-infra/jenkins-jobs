#!/bin/bash

set -ex

# Checking gerrit commits for fuel-qa
if [[ "${fuel_qa_gerrit_commit}" != "none" ]] ; then
  for commit in ${fuel_qa_gerrit_commit} ; do
    git fetch https://review.fuel-infra.org/openstack/fuel-qa "${commit}" && git cherry-pick FETCH_HEAD
  done
fi

# LP Bug:1549769 , seedclient should be started without activated virtualenv
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
echo "${ISO_PATH}"

export VENV_PATH="/home/jenkins/venv-nailgun-tests-2.9"

# Checking gerrit commits for fuel-devops
if [[ ${FUEL_DEVOPS_COMMIT} != "none" ]] ; then
  export VENV_PATH="${WORKSPACE}/devops-venv"
  # clean up previous run if exist
  rm -rf "${VENV_PATH}"

  virtualenv "${VENV_PATH}"
  . "${VENV_PATH}/bin/activate"

  # default pip is 1.4.1 which produces
  # ImportError: No module named packaging.version error
  pip install -U pip

  # Install fuel-devops
  git clone https://github.com/openstack/fuel-devops.git
  cd ./fuel-devops
  git checkout "${FUEL_DEVOPS_COMMIT}"
  if [[ "${fuel_devops_gerrit_commit}" != "none" ]] ; then
    for devops_commit in ${fuel_devops_gerrit_commit} ; do
      git fetch https://review.openstack.org/openstack/fuel-devops "${devops_commit}" && git cherry-pick FETCH_HEAD
    done
  fi
  pip install ./ --upgrade
  cd ..

  # Install fuel-qa requirements
  pip install -r ./fuelweb_test/requirements.txt --upgrade

  echo "=============================="
  pip freeze
  echo "=============================="

  cd "${WORKSPACE}"
  export DEVOPS_DB_NAME="${VENV_PATH}/fuel_devops.sqlite3"
  export DEVOPS_DB_ENGINE="django.db.backends.sqlite3"
  echo "export DEVOPS_DB_ENGINE='django.db.backends.sqlite3'" >> "${VENV_PATH}/bin/activate"
  echo "export DEVOPS_DB_NAME=\${VIRTUAL_ENV}/fuel_devops.sqlite3" >> "${VENV_PATH}/bin/activate"
# Ability to unset custom variables to avoid confusion with variables in case of manual check of job results.
  sed -i "s/\(unset VIRTUAL_ENV\)/\1 DEVOPS_DB_ENGINE DEVOPS_DB_NAME/" "${VENV_PATH}/bin/activate"
  django-admin.py syncdb --settings=devops.settings
  django-admin.py migrate devops --settings=devops.settings
fi

rm -rf logs/*

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT}

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
export ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

export PATH_TO_CERT="${WORKSPACE}/${ENV_NAME}.crt"
export PATH_TO_PEM="${WORKSPACE}/${ENV_NAME}.pem"

echo "Description string: ${TEST_GROUP} on ${NODE_NAME}: ${ENV_NAME}"

set +e

sh -x "utils/jenkins/system_tests.sh" \
  -t test \
  -w "${WORKSPACE}" \
  -V "${VENV_PATH}" \
  -j "${JOB_NAME}" \
  -o --group="${TEST_GROUP}" \
  -i "${ISO_PATH}"

test_exit_code=$?

set -e

#Removing old env
if [[ ${FUEL_DEVOPS_COMMIT} != "none" ]] ; then
  dos.py erase "${ENV_NAME}"
fi

exit ${test_exit_code}
