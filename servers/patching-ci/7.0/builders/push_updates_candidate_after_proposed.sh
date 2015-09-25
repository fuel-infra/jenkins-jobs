#!/bin/bash
set -ex

WORKSPACE="${WORKSPACE:-.}"

# mirror location
MIRROR_SOURCE_ARTIFACT="${WORKSPACE}/mirror_source.txt"
MIRROR_SOURCE="$(cat ${MIRROR_SOURCE_ARTIFACT})"
TARGET_SNAPSHOT_NAME=`echo ${MIRROR_SOURCE} | awk -F '/' '{print $NF}'`

# Getting a copy of snapshot
[ -z "$PROJECT_VERSION" ] && PROJECT_VERSION=7.0
[ -z "$MIRRORHOST" ] && MIRRORHOST=localhost
[ -z "$FILES_DIR" ] && FILES_DIR="snapshots"
case $DISTRO in
    "centos-6" )
          [ -z "$REMOTE_PATH" ] && REMOTE_PATH=rsync://${MIRRORHOST}/mirror-sync/mos-repos/centos/mos${PROJECT_VERSION}-centos6-fuel
          [ -z "$SNAPSHOT_NAME" ] && SNAPSHOT_NAME="cr-artifacts-${TIMESTAMP}"
          ;;
      "ubuntu" )
          [ -z "$REMOTE_PATH" ] && REMOTE_PATH=rsync://${MIRRORHOST}/mirror-sync/mos-repos/ubuntu/${PROJECT_VERSION}
          [ -z "$SNAPSHOT_NAME" ] && SNAPSHOT_NAME="${PROJECT_VERSION}-${TIMESTAMP}"
          ;;
             * )
          echo "Unsupported distribution"
          exit 1
          ;;
esac

SNAPSHOT_DIR=${WORKSPACE}/${DISTRO}-updates-candidate
[ -d "$SNAPSHOT_DIR" ] && rm -rf "$SNAPSHOT_DIR"
rsync -avPzt ${REMOTE_PATH}/${FILES_DIR}/${SNAPSHOT_NAME}/ "$SNAPSHOT_DIR"

# push mirror to all the locations
./trsync/push_snapshot_to_all_locations.py "${SNAPSHOT_DIR}/${TARGET_SNAPSHOT_NAME}" "${DISTRO}"
