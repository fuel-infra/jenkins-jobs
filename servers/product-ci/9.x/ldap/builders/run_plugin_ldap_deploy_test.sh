#!/bin/bash
#
set -ex

# Create temporary venv
rm -rf "${VENV_PATH}"
virtualenv "${VENV_PATH}"
source "${VENV_PATH}/bin/activate"

  # Upgrade default venv pip to last version
  pip install pip --upgrade

  # Temporary solution to solve error:
  #   'EntryPoint' object has no attribute 'resolve'
  pip install setuptools --upgrade

  # Install fuel-qa requirements
  pip install -r fuelweb_test/requirements.txt

  # get snapshot parameters into file
  rm -vf ldap_deploy_test.env
  export SNAPSHOT_ARTIFACTS_FILE=ldap_deploy_test.env
  env > ldap_deploy_test.env

  # get 9.x repositories
  ./utils/jenkins/conv_snapshot_file.py
  source extra_repos.sh

  export EXTRA_DEB_REPOS
  export EXTRA_RPM_REPOS
  export UPDATE_FUEL_MIRROR
  export UPDATE_MASTER

  # Required by mos-ci-deployment-scripts
  cp custom_framework/test_deploy_env.py system_test/tests/

  # Required by mos-ci-deployment-scripts
  export LDAP_CONFIG_FILE="${PLUGIN_CONFIG}.yaml"
  export SNAPSHOT_NAME="ready_ha_${PLUGIN_CONFIG}"
  export DISABLE_SSL="${DISABLE_SSL:-TRUE}"

  rm -rf logs/*

  # Generate description for job
  echo "Description string: ${TEST_GROUP?} on ${CUSTOM_VERSION?}"

  # Get deployment test configuration
  cp "${PLUGINS_PATH}"/tests/templates/* system_test/tests_templates/tests_configs/
  cp "${PLUGINS_PATH}/tests/plugins_config/${PLUGIN_CONFIG}.yaml" ./

  # Get plugin from snapshot
  pushd "${PLUGINS_PATH}"
    wget "${LDAP_PLUGIN_URL}/${LDAP_PLUGIN_RPM}"
  popd

  # Required by mos-ci-deployment-scripts
  pip install -r custom_framework/conf/deploy_requirements.txt
  # We need proper devops
  pip install -r fuelweb_test/requirements-devops-source.txt --upgrade

  # Store ENV name for post job which will kill timeouted tests
  export ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
  echo "export ENV_NAME=\"${ENV_NAME}\"" > \
       "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

  # Required by mos-ci-deployment-scripts
  ./run_system_test.py run system_test.deploy_env --with-config default

  # make snapshot if deployment is successful
  dos.py suspend "${ENV_NAME}"
  dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}"
  dos.py resume "${ENV_NAME}"

deactivate

# Creating env for tox
rm -rf venv_func
virtualenv venv_func
source venv_func/bin/activate
  pip install -U pip
  pip install tox
  # Run functional tests on deployed ldap plugin
  pushd custom_tests
    tox -e fuel-ldap -- -v -E "$ENV_NAME" -S "$SNAPSHOT_NAME"
  popd
deactivate