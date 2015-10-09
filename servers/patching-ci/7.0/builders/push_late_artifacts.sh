#!/bin/bash
set -ex

WORKSPACE="${WORKSPACE:-.}"

# detect timestamp
TIMESTAMP_ARTIFACT="${WORKSPACE:-}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"

# artifacts url
ARTIFACT_LIST_URL_ARTIFACT="${WORKSPACE}/late_artifacts_url.txt"
ARTIFACT_LIST_URL="$(cat ${ARTIFACT_LIST_URL_ARTIFACT})"

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
ssh ${SSH_OPTS} ${USER}@${PUBLISHER_HOST} << EOF
set -ex
ARTIFACT_LIST="\${HOME}/late_artifacts_list.txt"
wget -nv -O "\${ARTIFACT_LIST}" "${ARTIFACT_LIST_URL}"
ARTIFACTS_DIR="late_artifacts_${TIMESTAMP}"
mkdir -p "\${ARTIFACTS_DIR}"
wget -nv --directory-prefix="\${HOME}/\${ARTIFACTS_DIR}" -i "\${ARTIFACT_LIST}"
EOF
