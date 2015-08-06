#!/bin/bash
set -ex

WORKSPACE="${WORKSPACE:-.}"

# detect timestamp
TIMESTAMP_ARTIFACT="${WORKSPACE:-}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"

# artifacts url
ARTIFACT_LIST_URL_ARTIFACT="${WORKSPACE}/late_artifacts_url.txt"
ARTIFACT_LIST_URL="$(cat ${ARTIFACT_LIST_URL_ARTIFACT})"
ARTIFACT_LIST="${WORKSPACE}/late_artifacts_list.txt"

wget -nv -O "${ARTIFACT_LIST}" "${ARTIFACT_LIST_URL}"

#ARTIFACTS_DIR="${WORKSPACE}/late_artifacts_${TIMESTAMP}"
ARTIFACTS_DIR="late_artifacts_${TIMESTAMP}"
mkdir -p "${ARTIFACTS_DIR}"

wget -nv --directory-prefix="${WORKSPACE}/${ARTIFACTS_DIR}" -i "${ARTIFACT_LIST}"

OBS_URL="jenkins@obs-1.mirantis.com"
ARTIFACT_PATH="~"

# push mirror to obs-1
# TODO: use --link-dest
rsync ${RSYNC_EXTRA} -avPzt "${WORKSPACE}/${ARTIFACTS_DIR}" "${OBS_URL}:${ARTIFACT_PATH}/"
