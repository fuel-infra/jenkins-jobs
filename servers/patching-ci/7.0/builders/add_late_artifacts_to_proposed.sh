#!/bin/bash

set -xe

# detect timestamp
WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"
LATE_ARTIFACTS_URL_ARTIFACT="${WORKSPACE}/late_artifacts_url.txt"
LATE_ARTIFACTS_URL="$(cat ${LATE_ARTIFACTS_URL_ARTIFACT})"

UPDATES_CANDIDATE_MIRROR="${WORKSPACE}/updates-candidate_mirror.txt"
MIRROR_ARTIFACT="${WORKSPACE}/mirror_source.txt"
rm -f "${UPDATES_CANDIDATE_MIRROR}" "${MIRROR_ARTIFACT}"

OBS_HOST="obs-1.mirantis.com"
OBS_URL="jenkins@${OBS_HOST}"

SCRIPT_PATH="~"

# copy scripts to osci-obs host
# already copied by prepare_repos_for_iso.sh
#rsync ${RSYNC_EXTRA} -avPzt osci-mirrors/prepare-repos-for-iso ${OBS_URL}:${SCRIPT_PATH}
# and run script
CMD="${SCRIPT_PATH}/prepare-repos-for-iso/add-artifacts-to-proposed-${DISTRO}.sh ${TIMESTAMP}"
ssh "${OBS_URL}" "${CMD}"

echo "NOARTIFACT_MIRROR = http://${OBS_HOST}/mos/snapshots/${DISTRO}-${TIMESTAMP}" > "${UPDATES_CANDIDATE_MIRROR}"
echo "rsync://${OBS_HOST}/mos/snapshots/${DISTRO}-${TIMESTAMP}" > "${MIRROR_ARTIFACT}"
