#!/bin/bash
set -ex

WORKSPACE="${WORKSPACE:-.}"

# mirror location
MIRROR_SOURCE_ARTIFACT="${WORKSPACE}/mirror_source.txt"
MIRROR_SOURCE="$(cat ${MIRROR_SOURCE_ARTIFACT})"
TARGET_SNAPSHOT_NAME=`echo ${MIRROR_SOURCE} | awk -F '/' '{print $NF}'`

SNAPSHOT_DIR="${WORKSPACE}/repos"
if [ ! -d "${SNAPSHOT_DIR}" ]; then
    mkdir -p "${SNAPSHOT_DIR}"
fi

# pull mirror from obs-1
# TODO: use --link-dest
rsync ${RSYNC_EXTRA} -avPzt "${MIRROR_SOURCE}" "${SNAPSHOT_DIR}/"

# push mirror to all the locations
./trsync/push_snapshot_to_all_locations.py "${SNAPSHOT_DIR}/${TARGET_SNAPSHOT_NAME}" "${DISTRO}"
