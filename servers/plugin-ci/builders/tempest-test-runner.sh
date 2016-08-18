#!/bin/bash
#
#   :mod: `tempest-test-runner.sh` -- Start plugin deployment test
#   =============================================================
#
#   .. module:: tempest-test-runner.sh
#       :platform: Unix
#       :synopsis: Script used to start tempest tests over deployed environment
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Victor Ryzhenkin <vryzhenkin@mirantis.com>
#
#
#   This script is used to start openstack tempest over deployed environment.
#   This script uses plugin-deploy-test.sh module to prepare environment.
#   The execution hook script also uses common variables do determine environment which was deployed.
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

rm -rf logs/*

# Prepare variable for system test
ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
ENV_NAME="${ENV_NAME:0:68}"

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

# Copy plugin from build job
cp "${PLUGIN_FILE_PATH}" "${!PLUGIN_ENV_PATH_NAME}"

# Enable virtualenv
source "${VENV_PATH}/bin/activate"

# Store ENV name for post job which will kill timeouted tests
echo "export ENV_NAME=\"${ENV_NAME}\"" > \
     "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

# Execute test
bash -x "./utils/jenkins/system_tests.sh" \
     -t test -w "${WORKSPACE}" \
     -e "${ENV_NAME}" \
     -o --group="${TEST_GROUP}" \
     -i "${ISO_PATH}"

## Execute Tempest hook from the fuel-qa-plugin repo

bash -x "./utils/jenkins/tempest_tests.sh"