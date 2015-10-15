#!/bin/bash

set -xe

# detect timestamp
WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_TARGET_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP_TARGET="$(cat ${TIMESTAMP_TARGET_ARTIFACT})"

SCRIPT_PATH="/home/jenkins"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# copy scripts to publisher host
rsync -avPzt -e "ssh ${SSH_OPTS}" osci-mirrors/mos-proposed-to-updates ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}
rsync -avPzt -e "ssh ${SSH_OPTS}" trsync ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}

# and run script
case $DISTRO in
    "centos-6" ) SCRIPT_NAME="merge-rpm-repos.sh"
                 ;;
      "ubuntu" ) SCRIPT_NAME="merge-deb-repos.sh"
                 ;;
             * ) echo "Unsupported distribution"
                 exit 1
                 ;;
esac
CMD="export UPDATE_HEAD=${UPDATE_HEAD} REPO_BASE_PATH=${REPO_BASE_PATH} SIGKEYID=${SIGKEYID} REMOTE_HOST=\"${REMOTE_HOST}\""
CMD="${CMD}; ${SCRIPT_PATH}/mos-proposed-to-updates/${SCRIPT_NAME} ${TIMESTAMP_SOURCE} ${TIMESTAMP_TARGET}"

ssh ${SSH_OPTS} ${USER}@${PUBLISHER_HOST} ${CMD}
