#!/bin/bash

set -ex

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

rm -rf logs/*

export VENV_PATH=/home/jenkins/venv-nailgun-tests-2.9

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
if [ -z "$MAGNET_LINK" ]; then
    MAGNET_LINK=$(sed -e '/^MAGNET_LINK=/ s/^MAGNET_LINK=//' "${WORKSPACE:-.}/stable_iso_magnet_link.txt")
fi
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"
