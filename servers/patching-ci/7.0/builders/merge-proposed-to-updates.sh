#!/bin/bash

set -xe

pushd osci-mirrors
    CHANGE_REQUEST=12217
    REMOTE="origin"
    ORIGIN_HOST="$(git remote -v | awk -F '[:/]' '/^'${REMOTE}'.*fetch/ {print $4}')"
    ORIGIN_PORT="$(git remote -v | awk -F '[:/]' '/^'${REMOTE}'.*fetch/ {print $5}')"
    REF="$(ssh -p ${ORIGIN_PORT} ${ORIGIN_HOST} gerrit query --format TEXT --current-patch-set ${CHANGE_REQUEST} | awk '/ref:/ {print $NF}')"
    git fetch ${REMOTE} ${REF} && git cherry-pick FETCH_HEAD
popd

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
CMD="export REPO_BASE_PATH=${REPO_BASE_PATH} SIGKEYID=${SIGKEYID} REMOTE_HOST=\"${REMOTE_HOST}\""
CMD="${CMD}; ${SCRIPT_PATH}/mos-proposed-to-updates/${SCRIPT_NAME} ${TIMESTAMP_SOURCE} ${TIMESTAMP_TARGET}"

ssh ${SSH_OPTS} ${USER}@${PUBLISHER_HOST} ${CMD}
