#!/bin/bash

set -xe

# detect timestamp
WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_TARGET_ARTIFACT="${WORKSPACE}/timestamp.txt"
TIMESTAMP_TARGET="$(cat ${TIMESTAMP_TARGET_ARTIFACT})"
MIRROR_SOURCE_ARTIFACT="${WORKSPACE}/mirror_source.txt"

echo "rsync://${OBS_HOST}/mos/snapshots/${DISTRO}-updates-${TIMESTAMP_TARGET}" > ${MIRROR_SOURCE_ARTIFACT}

#OBS_HOST="obs-1.mirantis.com"
OBS_URL="jenkins@${OBS_HOST}"

SCRIPT_PATH="~"

# copy scripts to osci-obs host
# already copied by prepare_repos_for_iso.sh
rsync ${RSYNC_EXTRA} -avPzt osci-mirrors/mos-proposed-to-updates ${OBS_URL}:${SCRIPT_PATH}
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
CMD="${SCRIPT_PATH}/mos-proposed-to-updates/${SCRIPT_NAME} ${TIMESTAMP_SOURCE} ${TIMESTAMP_TARGET}"
ssh "${OBS_URL}" "${CMD}"
