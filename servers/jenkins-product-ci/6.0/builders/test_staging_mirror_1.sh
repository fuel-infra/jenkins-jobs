#!/bin/bash

set -ex

if [ -z "$MIRROR" ]; then
    echo "No MIRROR"
    exit -1
fi

if [ -z "$MIRROR_VERSION" ]; then
    echo "No MIRROR_VERSION"
    exit -1
fi

if [ -z "$MIRROR_BASE" ]; then
    echo "No MIRROR_BASE"
    exit -1
fi

PARAM_FILE=$WORKSPACE/mirror_staging.txt
rm -f $PARAM_FILE

echo "MIRROR = ${MIRROR}" >>$PARAM_FILE
echo "MIRROR_VERSION = ${MIRROR_VERSION}" >>$PARAM_FILE
echo "STABLE_VERSION = ${MIRROR_VERSION}" >>$PARAM_FILE
echo "MIRROR_BASE = $MIRROR_BASE" >>$PARAM_FILE
echo "fuelmain_gerrit_commit = ${extra_commits}" >>$PARAM_FILE
echo "BUILD_MIRROR_URL = ${BUILD_MIRROR_URL}" >> $PARAM_FILE

if [ -n "$MIRROR_UBUNTU" ]; then
    echo "MIRROR_UBUNTU = $MIRROR_UBUNTU" >>$PARAM_FILE
fi
if [ "$MIRROR_UBUNTU_SECURITY" = "MIRROR_UBUNTU" ]; then
    echo "MIRROR_UBUNTU_SECURITY = $MIRROR_UBUNTU" >>$PARAM_FILE
elif [ -n "$MIRROR_UBUNTU_SECURITY" ]; then
    echo "MIRROR_UBUNTU_SECURITY = $MIRROR_UBUNTU_SECURITY" >>$PARAM_FILE
fi
if [ -n "$USE_MIRROR" ]; then
    echo "USE_MIRROR = $USE_MIRROR" >>$PARAM_FILE
fi

rm -f build_description.*
