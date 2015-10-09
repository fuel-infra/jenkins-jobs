#!/bin/bash

set -xe

# detect timestamp
WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"

CHANGE_REQUESTS="12211 12217"
for CHANGE_REQUEST in $CHANGE_REQUESTS; do
    pushd osci-mirrors
        REMOTE="origin"
        ORIGIN_HOST="$(git remote -v | awk -F '[:/]' '/^'${REMOTE}'.*fetch/ {print $4}')"
        ORIGIN_PORT="$(git remote -v | awk -F '[:/]' '/^'${REMOTE}'.*fetch/ {print $5}')"
        REF="$(ssh -p ${ORIGIN_PORT} ${ORIGIN_HOST} gerrit query --format TEXT --current-patch-set ${CHANGE_REQUEST} | awk '/ref:/ {print $NF}')"
        git fetch ${REMOTE} ${REF} && git cherry-pick FETCH_HEAD
    popd
done

SCRIPT_PATH="/home/jenkins"
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# copy scripts to publisher host
rsync -avPzt -e "ssh ${SSH_OPTS}" osci-mirrors/prepare-repos-for-iso ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}
rsync -avPzt -e "ssh ${SSH_OPTS}" osci-mirrors/mos-proposed-to-updates/lock-functions.sh ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}/prepare-repos-for-iso/
rsync -avPzt -e "ssh ${SSH_OPTS}" trsync ${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}

case $DISTRO in
    "centos-6" ) SCRIPT_NAME="update-centos-repo.sh"
                 ;;
      "ubuntu" ) SCRIPT_NAME="update-ubuntu-repo.sh"
                 ;;
             * ) echo "Unsupported distribution"
                 exit 1
                 ;;
esac

# and run script
CMD="export TIMESTAMP=${TIMESTAMP} REMOTE_HOST="${REMOTE_HOST}"; ${SCRIPT_PATH}/prepare-repos-for-iso/${SCRIPT_NAME} ${TIMESTAMP}"
ssh ${SSH_OPTS} ${USER}@${PUBLISHER_HOST} ${CMD}
