#!/bin/bash
#
#   :mod: `plugin-ldap-deploy-test.sh` -- Start plugin deployment test
#   =============================================================
#
#   .. module:: plugin-ldap-deploy-test.sh
#       :platform: Unix
#       :synopsis: Script used to start deployment test
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Artur Kaszuba <akaszuba@mirantis.com>, Nikita Karpin <mkarpin@mirantis.com>
#
#
#   This script is used to start single deployment test with specified
#   test group
#
#
#   .. envvar::
#       :var  PLUGINS: Path to directory used to store plugins required by test
#       :var  PLUGIN_FILE_PATH: Path to file with plugin built by build job
#       :var  PLUGIN_ENV_PATH_NAME: Environment name used by test group to
#                                   store plugin file path
#       :var  VENV_PATH: Path to directory with already created virtualenv
#                        and installed inside test framework
#       :var  TEST_GROUP: Test group used in test
#       :var  ISO_PATH: Path to ISO file used in test
#       :var  ENV_PREFIX: Prefix used to create test environment name
#       :var  OPENSTACK_RELEASE: Backend distribution used in test
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::run_tests: true
#

set -ex


#get 9.x repositories
wget "${REPO_SNAPSHOTS_URL}"
./utils/jenkins/conv_snapshot_file.py
source extra_repos.sh

export EXTRA_DEB_REPOS
export EXTRA_RPM_REPOS
export UPDATE_FUEL_MIRROR
export UPDATE_MASTER

# Required by mos-ci-deployment-scripts
PLUGIN_DIR=$(dirname "${PLUGIN_FILE_PATH}")
cp "${PLUGIN_DIR}"/tests/templates/* system_test/tests_templates/tests_configs/
cp "${PLUGIN_DIR}/tests/plugins_config/${PLUGIN_CONFIG}.yaml" ./

# Required by mos-ci-deployment-scripts
git clone "${CUSTOM_FRAMEWORK_REPO}" --branch "${CUSTOM_FRAMEWORK_BRANCH}" custom_framework
cp custom_framework/test_deploy_env.py system_test/tests/

# Required by mos-ci-deployment-scripts
export LDAP_CONFIG_FILE="${PLUGIN_CONFIG}.yaml"
export DISABLE_SSL="${DISABLE_SSL:-TRUE}"
export PLUGINS_PATH=plugins_data

rm -rf logs/*

# Prepare variable for system test
# ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
# ENV_NAME="${ENV_NAME:0:68}"

# Generate description for job
echo "Description string: ${TEST_GROUP} on ${ISO_VERSION_STRING}"

export MAKE_SNAPSHOT=false

# Define directory used to store plugins
PLUGINS=plugins_data

# Create the directory that will contain the plugin packages
mkdir -p "${PLUGINS}"

# Set variable with built plugin file path
# it is required by system test
export ${PLUGIN_ENV_PATH_NAME}="${PLUGINS}/${PLUGIN_FILE}"

# Download plugin file from mirror
wget "${PLUGIN_URL}" -O "${!PLUGIN_ENV_PATH_NAME}"

# Enable virtualenv
source "${VENV_PATH}/bin/activate"

# Required by mos-ci-deployment-scripts
pip install -r custom_framework/conf/deploy_requirements.txt
# We need proper devops
pip install -r fuelweb_test/requirements-devops-source.txt --upgrade

# Store ENV name for post job which will kill timeouted tests
echo "export ENV_NAME=\"${ENV_NAME}\"" > \
     "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

# Required by mos-ci-deployment-scripts
./run_system_test.py run "system_test.${TEST_GROUP}" --with-config default

# make snapshot if deployment is successful
dos.py suspend "${ENV_NAME}"
dos.py snapshot "${ENV_NAME}" "${SNAPSHOT_NAME}"
dos.py resume "${ENV_NAME}"

deactivate

# Execute test
#bash -x "./utils/jenkins/system_tests.sh" \
#     -t test -w "${WORKSPACE}" \
#     -e "${ENV_NAME}" \
#     -o --group="${TEST_GROUP}" \
#     -i "${ISO_PATH}"

#creating env for tox
virtualenv --clear venv_func
source venv_func/bin/activate
pip install -U pip
pip install tox

# Run functional tests on deployed ldap plugin
rm -rf custom_tests
git clone "${CUSTOM_TESTS_REPO}" custom_tests
pushd custom_tests

tox -e fuel-ldap -- -v -E "$ENV_NAME" -S "$SNAPSHOT_NAME"

deactivate
