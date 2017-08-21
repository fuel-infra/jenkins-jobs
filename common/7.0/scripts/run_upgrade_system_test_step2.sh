#!/bin/bash
# Use -k to reuse environment
source "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

export MAKE_SNAPSHOT="false"

export TARBALL_PATH=$(seedclient-wrapper -d -m "${UPGRADE_TARBALL_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${TARBALL_PATH}" | cut -d '-' -f 2-4)
echo "Description string: ${VERSION_STRING}"

export UPGRADE_FUEL_FROM=$(basename "${ISO_PATH}" | cut -d '-' -f 2 | sed s/.iso//g)
export UPGRADE_FUEL_TO=$(basename "${TARBALL_PATH}" | cut -d '-' -f 2)

export VENV_PATH="/home/jenkins/qa-venv-7.0"

sh -x "UPGRADE/utils/jenkins/system_tests.sh" -k -t test -w "${WORKSPACE}/UPGRADE" -e "${ENV_NAME}" -o --group="${UPGRADE_TEST_GROUP}" -i "${ISO_PATH}"
