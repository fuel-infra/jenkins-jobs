#!/bin/bash

set -ex

rm -rf logs/*

ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: $TEST_GROUP on $VERSION_STRING"

sh -x "utils/jenkins/system_tests.sh" -w "${WORKSPACE}" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"

# clean up if tests were successful
source "${VENV_PATH}"/bin/activate
  dos.py erase "${ENV_NAME}"
deactivate