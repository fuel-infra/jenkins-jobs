#!/bin/bash
#
#   :mod: `plugin-deploy-test.sh` -- Start plugin deployment test
#   =============================================================
#
#   .. module:: plugin-deploy-test.sh
#       :platform: Unix
#       :synopsis: Script used to start deployment test
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Artur Kaszuba <akaszuba@mirantis.com>
#
#
#   This script is used to start single deployment test with specified
#   test group
#
#
#   .. envvar::
#       :var  PLUGINS: Path to directory used to store plugins required by test
#             Default: plugins_data
#       :var  PLUGIN_FILE_PATH: Path to file with plugin built by build job
#             file may not exist.
#       :var  PLUGIN_ENV_PATH_NAME: Environment name used by test group to
#                                   store plugin file path
#             File should exist before or after script run
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
PLUGINS=${PLUGINS:-plugins_data}

# Create the directory that will contain the plugin packages
mkdir -p "${PLUGINS}"

# Set variable with built plugin file path
# it is required by system test
export ${PLUGIN_ENV_PATH_NAME}="${PLUGINS}/${PLUGIN_FILE}"

# Copy plugin from build job,
# not fail if source file not exist - it could be copyed before
if [ -f "${PLUGIN_FILE_PATH}" ]; then
    cp -v "${PLUGIN_FILE_PATH}" "${!PLUGIN_ENV_PATH_NAME}"
fi
# But check, if destination file actually exists
if [ ! -f "${!PLUGIN_ENV_PATH_NAME}" ]; then
     echo "ERROR: File ${!PLUGIN_ENV_PATH_NAME} not exist!"
     exit 1
fi

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
