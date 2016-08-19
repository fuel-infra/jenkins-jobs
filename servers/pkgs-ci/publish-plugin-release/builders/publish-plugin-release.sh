#!/bin/bash
set -ex

########################################################
#
# Used variables
#
# REPO_ROOT     : Common path to all repositories
#               : E.g. /home/jenkins/pubrepos
#
# SYNC_PATH     : Path to the repository, relative to REPO_ROOT
#               : E.g. /mos-plugins/centos/9.0
#
# HOSTS_TO_SYNC : Host list sync to
#               : E.g. "rsync://seed-cz1.fuel-infra.org/mirror-sync \
#               :      rsync://seed-us1.fuel-infra.org/mirror-sync"
#
# TRSYNC_DIR    : local path to trsync project
#
# SNAPSHOT_DIR  : Name for folder, which contains snapshots.
#               : Default is "snapshots"

function exit_with_error() {
    >&2 echo "$@"
    exit 1
}

function job_lock() {
    [ -z "$1" ] && exit_with_error "Lock file is not specified"
    local LOCKFILE=$1
    shift
    fd=15
    eval "exec $fd>$LOCKFILE"
    case $1 in
        "set")
            flock -x -n $fd \
                || exit_with_error "Process already running. Lockfile: $LOCKFILE"
            ;;
        "unset")
            flock -u $fd
            rm -f "$LOCKFILE"
            ;;
    esac
}

export LANG=C

########################################################
#
# Initialize trsync
#

VENV_PATH=$TRSYNC_DIR/.venv
virtualenv "$VENV_PATH"
source "$VENV_PATH/bin/activate"
pip install -r "$TRSYNC_DIR/requirements.txt"
pushd "${TRSYNC_DIR}" &>/dev/null
    python setup.py build
    python setup.py install
popd &>/dev/null

########################################################
#
# Initialize local variables
#
TIMESTAMP=$(date "+%Y-%m-%d-%H%M%S")
SNAPSHOT_DIR=${SNAPSHOT_DIR:-snapshots}

mkdir -p "${REPO_ROOT}${SYNC_PATH}"
LOCKFILE="${REPO_ROOT}${SYNC_PATH}.lock"

# Lock the repository to aviod race conditions
job_lock "${LOCKFILE}" set

    if [ "$RESYNC_ONLY" != "true" ]; then
        if [ -n "$URL" ]; then
            wget -q "$URL" -O "$WORKSPACE/plugin.rpm" \
                || exit_with_error "Can't download package"
        fi
        if [ -f "$WORKSPACE/plugin.rpm" ]; then
            PACKAGENAME=$(rpm -qp --queryformat "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm" "$WORKSPACE/plugin.rpm")
            [ -n "$PACKAGENAME" ] && mv "$WORKSPACE/plugin.rpm" "${REPO_ROOT}${SYNC_PATH}/${PACKAGENAME}"
            createrepo --pretty --database --update -o "${REPO_ROOT}${SYNC_PATH}" "${REPO_ROOT}${SYNC_PATH}"
        else
            exit_with_error "RPM file to publish is not defined"
        fi
    fi

    for host in $HOSTS_TO_SYNC ; do
        trsync push "${REPO_ROOT}${SYNC_PATH}" \
            -d "${host}/${SYNC_PATH%/*}" \
            -s "${SYNC_PATH##*/}" \
            --init-directory-structure \
            --snapshot-dir "$SNAPSHOT_DIR" \
            --timestamp "$TIMESTAMP" \
            || failedhosts="${failedhosts} ${host}"
    done

job_lock "${LOCKFILE}" unset

[ -n "$failedhosts" ] && failedmessage="${failedmessage}
FAILED PATH: ${SYNC_PATH}
FAILED HOSTS: ${failedhosts}"
if [ -n "$failedmessage" ] ; then
    exit_with_error "$failedmessage"
fi
