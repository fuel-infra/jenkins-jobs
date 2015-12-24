#!/bin/bash

set -ex

rm -rf logs/*

ISO_PATH=$(seedclient.py -d -m "${ISO_TORRENT}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(readlink "${ISO_PATH}" | cut -d '-' -f 3-4)
echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

sh -x "utils/jenkins/system_tests.sh" \
  -t test \
  -w "${WORKSPACE}" \
  -V "${VENV_PATH}" \
  -e "${ENV_NAME}" \
  -o --group="${TEST_GROUP}" \
  -i "${ISO_PATH}"
