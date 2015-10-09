#!/bin/bash -ex

WORKSPACE="${WORKSPACE:-.}"
TIMESTAMP_ARTIFACT="${WORKSPACE}/timestamp.txt"
rm -f "$TIMESTAMP_ARTIFACT"


TIMESTAMP_REGEXP='[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}'

export SAVE_LATEST_DAYS=${SAVE_LATEST_DAYS:-61}
export WARN_DATE=$(date --utc "+%Y%m%d" -d "$SAVE_LATEST_DAYS days ago")

if [ -z "${TIMESTAMP}" ]; then
    export TIMESTAMP=$(date --utc "+%Y-%m-%d-%H%M%S")
else
    # check that TIMESTAMP variable matches regexp
    echo "${TIMESTAMP}" | grep -E "^${TIMESTAMP_REGEXP}$"
fi

echo "${TIMESTAMP}" > "${TIMESTAMP_ARTIFACT}"

case $DISTRO in
    "centos-6" )
        NOARTIFACT_MIRROR_ARTIFACT="${WORKSPACE}/noartifact_mirror.txt"
        rm -f "${NOARTIFACT_MIRROR_ARTIFACT}"
        CURRENT_PROPOSED_SNAPSHOT=$(rsync -l rsync://${REMOTE_HOST%% *}/mirror/mos-repos/centos/mos7.0-centos6-fuel/snapshots/proposed-latest | awk '{print $NF}')
        echo "NOARTIFACT_MIRROR = http://${REMOTE_HOST%% *}/mos-repos/centos/mos7.0-centos6-fuel/snapshots/${CURRENT_PROPOSED_SNAPSHOT}" > "${NOARTIFACT_MIRROR_ARTIFACT}"
        ;;
esac
