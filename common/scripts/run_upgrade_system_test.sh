#!/bin/bash

set -e

VENV_PATH=/home/jenkins/venv-nailgun-tests
export CONNECTION_STRING='qemu+tcp://127.0.0.1:16509/system'
export ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER

rm -rf logs/*

ISO_PATH=`seedclient-wrapper -d -m "${BASE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}"`

export MAKE_SNAPSHOT=true

sh -x "BASE/utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE/BASE" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"

echo "Description string: $TEST_GROUP on $VERSION_STRING"

export MAKE_SNAPSHOT=false

export TARBALL_PATH=`seedclient-wrapper -d -m "${UPGRADE_TARBALL_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}"`

export UPGRADE_FUEL_FROM=`basename $ISO_PATH | cut -d '-' -f 2`
export UPGRADE_FUEL_TO=`basename $TARBALL_PATH | cut -d '-' -f 2`

# Use -k to reuse environment
sh -x "UPGRADE/utils/jenkins/system_tests.sh" -k -t test -w "$WORKSPACE/UPGRADE" -e "$ENV_NAME" -o --group="$UPGRADE_TEST_GROUP" -i "$ISO_PATH"
