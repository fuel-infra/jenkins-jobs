#!/bin/bash
#
#  :mod:`merge-proposed-to-updates` -- A Wrapper to sync updates repo
#  ==================================================================
#
#  .. module:: merge-proposed-to-updates
#      :platform: Ubuntu 14.04
#      :synopsis: syncing updates repository
#  .. versionadded:: MOS-6.1 patching
#  .. versionchanged:: MOS-9.0 patching
#  .. author:: Maksim Rasskazov <mrasskazov@mirantis.com>
#
#  .. envvar::
#      :var  CUSTOM_SYMLINK: create custom symlink for updates repo
#      :type CUSTOM_SYMLINK: str
#      :var  DISTRO: distributive name
#      :type DISTRO: str
#      :var  PROJECT_VERSION: MOS version
#      :type PROJECT_VERSION: float
#      :var  PUBLISHER_HOST: publisher host
#      :type PUBLISHER_HOST: str
#      :var  REMOTE_HOST: array of mirror hosts to sync to
#      :type REMOTE_HOST: arr[str]
#      :var  REMOTE_PATH: rsync path to repos on mirror hosts
#      :type REMOTE_PATH: path
#      :var  REPO_BASE_PATH: path to repos on publisher
#      :type REPO_BASE_PATH: path
#      :var  SCRIPT_PATH: path on publisher for trsync and syncing scripts
#      :type SCRIPT_PATH: path
#      :var  SIGKEYID: repo siging key id on publisher
#      :type SIGKEYID: str
#      :var  TIMESTAMP_SOURCE: timestamp of snapshot to download
#      :type TIMESTAMP_SOURCE: str
#      :var  UPDATE_HEAD: update head repository symlink
#      :type UPDATE_HEAD: bool
#      :var  USER: rsync user, defaults to jenkins
#      :type USER: str
#
#  .. affects::
#      :file noartifact_mirror.txt: stores URL of used noartifact mirror
#

set -ex

# detect timestamp
TIMESTAMP_TARGET_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP_TARGET="$(cat "${TIMESTAMP_TARGET_ARTIFACT}")"

# log noartifact mirror
case $DISTRO in
    "centos-7" )
        NOARTIFACT_MIRROR_ARTIFACT="${WORKSPACE}/noartifact_mirror.txt"
        rm -f "${NOARTIFACT_MIRROR_ARTIFACT}"
        # fixme: line wrapping, let's see this working first
        # shellcheck disable=SC2086
        # take the first host
        CURRENT_PROPOSED_SNAPSHOT=$(rsync -l rsync://${REMOTE_HOST%% *}/mirror/mos-repos/centos/mos${PROJECT_VERSION}-centos7-fuel/snapshots/proposed-latest | awk '{print $NF}')
        echo "NOARTIFACT_MIRROR = http://${REMOTE_HOST%% *}/mos-repos/centos/mos${PROJECT_VERSION}-centos7-fuel/snapshots/${CURRENT_PROPOSED_SNAPSHOT}" > "${NOARTIFACT_MIRROR_ARTIFACT}"
        ;;
esac

SCRIPT_PATH="/home/jenkins"
SSH_OPTS=(-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no)
# copy scripts to publisher host
rsync -avPzt -e "ssh ${SSH_OPTS[*]}" osci-mirrors/mos-proposed-to-updates "${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}"
rsync -avPzt -e "ssh ${SSH_OPTS[*]}" trsync "${USER}@${PUBLISHER_HOST}:${SCRIPT_PATH}"

# and run script
case $DISTRO in
    "centos-7" ) SCRIPT_NAME="merge-rpm-repos.sh"
                 REMOTE_PATH="/mos-repos/centos/mos${PROJECT_VERSION}-centos7-fuel"
                 ;;
      "ubuntu" ) SCRIPT_NAME="merge-deb-repos.sh"
                 REMOTE_PATH="/mos-repos/ubuntu/${PROJECT_VERSION}"
                 ;;
             * ) echo "Unsupported distribution"
                 exit 1
                 ;;
esac
#fixme: line wrapping, let's see this working first
CMD="export UPDATE_HEAD=${UPDATE_HEAD} PROJECT_VERSION=${PROJECT_VERSION} REMOTE_PATH=${REMOTE_PATH} REPO_BASE_PATH=${REPO_BASE_PATH} SIGKEYID=${SIGKEYID} REMOTE_HOST=\"${REMOTE_HOST}\""
CMD="${CMD}; ${SCRIPT_PATH}/mos-proposed-to-updates/${SCRIPT_NAME} ${TIMESTAMP_SOURCE} ${TIMESTAMP_TARGET} ${CUSTOM_SYMLINK}"

# shellcheck disable=SC2029
# intended to expand on client side
ssh "${SSH_OPTS[@]}" "${USER}@${PUBLISHER_HOST}" "${CMD}"
