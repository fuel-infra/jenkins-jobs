#!/bin/bash

set -xe

# detect timestamp
WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"

NOARTIFACT_MIRROR_ARTIFACT="${WORKSPACE}/noartifact_mirror.txt"
MIRROR_ARTIFACT="${WORKSPACE}/mirror_source.txt"
rm -f "${NOARTIFACT_MIRROR_ARTIFACT}" "${MIRROR_ARTIFACT}"

OBS_URL="jenkins@${OBS_HOST}"

SCRIPT_PATH="~"

# copy scripts to osci-obs host
rsync ${RSYNC_EXTRA} -avPzt osci-mirrors/prepare-repos-for-iso ${OBS_URL}:${SCRIPT_PATH}
# and run script
CMD="env TIMESTAMP=${TIMESTAMP} ${SCRIPT_PATH}/prepare-repos-for-iso/update-${DISTRO}-repo.sh"
ssh "${OBS_URL}" "${CMD}"

echo "NOARTIFACT_MIRROR = http://obs-1.mirantis.com/mos/snapshots/${DISTRO}-noartifacts-${TIMESTAMP}" > "${NOARTIFACT_MIRROR_ARTIFACT}"
# TODO: rsync link
echo "rsync://obs-1.mirantis.com/mos/snapshots/${DISTRO}-noartifacts-${TIMESTAMP}" > "${MIRROR_ARTIFACT}"
