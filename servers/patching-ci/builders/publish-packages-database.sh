#!/bin/bash -ex

#####################################################################
#
# Used variables
#
# MIRROR_HOST   : mirror host sync from
#               : Optional. Default is mirror.fuel-infra.org
#
# HOSTS_TO_SYNC : hosts sync to
#               : Optional. Default is "seed-cz1.fuel-infra.org seed-us1.fuel-infra.org"
#
# FILE          : name of database file
#               : e.g. 7.0-centos-mu-2.sqlite
#
# DISTRO        : type of OS
#               : e.g. "centos" or "ubuntu"
#
# DRY_RUN       : All the changes will not be pushed on mirror if
#                 this option is "true"
#

die() {
    echo "$@"
    exit 1
}

##################################################
#
# Initialize local variables
#

export LANG=C
RSYNC_OPTS=(-avPzt --delete --chmod=a+rx)
RSYNC_OPTS_REMOTE=(-aHv --delete --no-perms --no-owner --no-group)

DRY_RUN_OPT=''
[ "${DRY_RUN}" == "true" ] && DRY_RUN_OPT="--dry-run"

MIRROR_HOST=${MIRROR_HOST:-"mirror.fuel-infra.org"}
HOSTS_TO_SYNC=${HOSTS_TO_SYNC:-"mirror.seed-cz1.fuel-infra.org \
mirror.seed-us1.fuel-infra.org"}
DST_DIR="mcv/mos"

##################################################
#
# Clone existing reports from mirror to
# ${WORKSPACE} directory
#

rsync "${RSYNC_OPTS[@]}" "rsync://${MIRROR_HOST}/mirror/mcv" "${WORKSPACE}" || \
die "ERROR: Mirroring of ${MIRROR_HOST} failed!"

##################################################
#
# Create directory for new release if need and
# copy new report to target directory
#

[ ! -d "${DST_DIR}/$RELEASE_VERSION" ] && mkdir "${DST_DIR}/$RELEASE_VERSION"

pushd "${DST_DIR}/$RELEASE_VERSION"
    if [ ! -f "$FILE" ] ; then
        cp "${WORKSPACE}/${FILE}" "."
    else
        die "File $FILE already exist!"
    fi
    ln -sf "${FILE}" "${DISTRO}-latest.sqlite"
popd

##################################################
#
# Sync new repository report to the hosts
#

for DST_HOST in ${HOSTS_TO_SYNC} ; do
    rsync "${RSYNC_OPTS_REMOTE[@]}" ${DRY_RUN_OPT} "${DST_DIR}/" \
    "rsync://${DST_HOST}/mirror-sync/${DST_DIR}/"
done
