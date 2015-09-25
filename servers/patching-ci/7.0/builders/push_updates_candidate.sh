#!/bin/bash
set -ex

WORKSPACE="${WORKSPACE:-.}"

# detect timestamp
TIMESTAMP_ARTIFACT="${WORKSPACE:-}/timestamp.txt"
TIMESTAMP="$(cat ${TIMESTAMP_ARTIFACT})"

# mirror location
MIRROR_ARTIFACT="${WORKSPACE}/mirror_source.txt"
MIRROR="$(cat ${MIRROR_ARTIFACT})"

SNAPSHOT_DIR="${WORKSPACE}/repos"
mkdir -p "${SNAPSHOT_DIR}"


# pull mirror from obs-1
# TODO: use --link-dest
rsync ${RSYNC_EXTRA} -avPzt "${MIRROR}" "${SNAPSHOT_DIR}/"

# push mirror to all the locations
case "${DISTRO}" in
    ubuntu)
        ./trsync/push_snapshot_to_all_locations.py "${SNAPSHOT_DIR}/${DISTRO}-noartifacts-${TIMESTAMP}" "${DISTRO}"
        ;;
    centos-6)
        ./trsync/push_snapshot_to_all_locations.py "${SNAPSHOT_DIR}/${DISTRO}-${TIMESTAMP}" "${DISTRO}"
        ;;
    *)
        echo "Wrong \$DISTRO == '${DISTRO}'"
        exit 1
        ;;
esac

#    "snapshots/${DISTRO}.updates-candidate"

echo "MIRROR = http://${OBS_HOST}/mos/snapshots/${DISTRO}-${TIMESTAMP}" > "${MIRROR_ARTIFACT}"
