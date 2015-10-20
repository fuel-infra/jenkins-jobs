#!/bin/bash

set -xe

# detect timestamp
WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"

SCRIPT_PATH="/home/jenkins"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# copy scripts to publisher host
rsync -avPzt -e "ssh ${SSH_OPTS}" osci-mirrors/prepare-repos-for-iso ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}
rsync -avPzt -e "ssh ${SSH_OPTS}" osci-mirrors/mos-proposed-to-updates/lock-functions.sh ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}/prepare-repos-for-iso/
rsync -avPzt -e "ssh ${SSH_OPTS}" trsync ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}

case $DISTRO in
    "centos-6" ) # Add dowloaded artifacts to proposed repository
                 if [ "$BUILD_LATE_ARTIFACTS" == "true" ] ; then
                     CMD="export SIGKEYID=${SIGKEYID} ; ${SCRIPT_PATH}/prepare-repos-for-iso/add-artifacts-to-proposed-centos-6.sh ${TIMESTAMP}"
                     ssh ${SSH_OPTS} ${USER}@${PUBLISHER_HOST} ${CMD}
                 fi
                 SCRIPT_NAME="update-centos-repo.sh"
                 ;;
      "ubuntu" ) SCRIPT_NAME="update-ubuntu-repo.sh"
                 ;;
             * ) echo "Unsupported distribution"
                 exit 1
                 ;;
esac

# and run script
CMD="export UPDATE_HEAD=${UPDATE_HEAD} TIMESTAMP=${TIMESTAMP} SIGKEYID=${SIGKEYID} REMOTE_HOST=\"${REMOTE_HOST}\"; ${SCRIPT_PATH}/prepare-repos-for-iso/${SCRIPT_NAME} ${TIMESTAMP}"
ssh ${SSH_OPTS} ${USER}@${PUBLISHER_HOST} ${CMD}
