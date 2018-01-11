#!/bin/bash

set -ex

rm -rf logs/*

ENV_PREFIX="${ENV_PREFIX:0:56}"
ENV_NAME="${ENV_PREFIX}.${BUILD_ID}"
ENV_NAME=${ENV_NAME:0:60}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: $TEST_GROUP on $VERSION_STRING"

### PLUGINS

PLUGIN_DIR=plugins

# clean old plugins dir
rm -rf ${PLUGIN_DIR}
mkdir -p ${PLUGIN_DIR}

export EXAMPLE_PLUGIN_PATH="${PLUGIN_DIR}/fuel_plugin_example.fp"
export EXAMPLE_PLUGIN_V3_PATH="${PLUGIN_DIR}/fuel_plugin_example_v3.noarch.rpm"
export EXAMPLE_PLUGIN_V4_PATH="${PLUGIN_DIR}/fuel_plugin_example_v4_hotpluggable.noarch.rpm"
export SEPARATE_SERVICE_DB_PLUGIN_PATH="${PLUGIN_DIR}/detach-database-1.1-1.1.0-1.noarch.rpm"
export SEPARATE_SERVICE_RABBIT_PLUGIN_PATH="${PLUGIN_DIR}/detach-rabbitmq-1.0-1.0.1-1.noarch.rpm"
export SEPARATE_SERVICE_KEYSTONE_PLUGIN_PATH="${PLUGIN_DIR}/detach-keystone-1.0-1.0.2-1.noarch.rpm"

curl -s "${EXAMPLE_PLUGIN_URL}" -o ${EXAMPLE_PLUGIN_PATH}
curl -s "${EXAMPLE_PLUGIN_V3_URL}" -o ${EXAMPLE_PLUGIN_V3_PATH}
curl -s "${EXAMPLE_PLUGIN_V4_URL}" -o ${EXAMPLE_PLUGIN_V4_PATH}
curl -s "${SEPARATE_SERVICE_DB_PLUGIN_URL}" -o ${SEPARATE_SERVICE_DB_PLUGIN_PATH}
curl -s "${SEPARATE_SERVICE_RABBIT_PLUGIN_URL}" -o ${SEPARATE_SERVICE_RABBIT_PLUGIN_PATH}
curl -s "${SEPARATE_SERVICE_KEYSTONE_PLUGIN_URL}" -o ${SEPARATE_SERVICE_KEYSTONE_PLUGIN_PATH}

### /PLUGINS

sh -x "utils/jenkins/system_tests.sh" -w "${WORKSPACE}" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"

# clean up if tests were successful
source "${VENV_PATH}"/bin/activate
  dos.py erase "${ENV_NAME}"
deactivate