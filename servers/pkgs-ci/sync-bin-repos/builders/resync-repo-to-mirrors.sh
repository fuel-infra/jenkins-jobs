#!/bin/bash
set -ex

########################################################
#
# Used variables
#
# SRCURI        : URI of rsync root of source repository
#               : E.g "rsync://osci-mirror-srt.srt.mirantis.net/mirror"
#
# SRCPATHS      : List of rsync root relative path to the repositories
#               : E.g "mos-repos/ubuntu/7.0 mos-repos/ubuntu/8.0 \
#               :      extras/murano-plugin-repos/release/*/ubuntu/9.0"
#
# HOSTS_TO_SYNC : host list sync to
#               : E.g. "rsync://seed-cz1.fuel-infra.org/mirror-sync \
#               :      rsync://seed-us1.fuel-infra.org/mirror-sync"
#
# TRSYNC_DIR    : local path to trsync project
#
# REPOCACHE_DIR : local directory contains cashed repositories
#               : Optional. Default is $(current_dir)/data
#


function exit_with_error() {
    >&2 echo "$@"
    exit 1
}

function job_lock() {
    [ -z "$1" ] && exit_with_error "Lock file is not specified"
    local LOCKFILE=/tmp/$1
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
            ;;
        "wait")
            TIMEOUT=${2:-3600}
            echo "Waiting of concurrent process (lockfile: $LOCKFILE, timeout = $TIMEOUT seconds) ..."
            if flock -x -w "$TIMEOUT" $fd ; then
                echo DONE
            else
                exit_with_error "Timeout error (lockfile: $LOCKFILE)"
            fi
            ;;
    esac
}

export LANG=C
WRK_DIR=$(pwd)

########################################################
#
# Initialize trsync
#
[ -z "$TRSYNC_DIR" ] && TRSYNC_DIR=${WRK_DIR}/trsync

VENV_PATH=${TRSYNC_DIR}/.venv
if [ ! -d "$VENV_PATH" ] ; then
    mkdir -p "$VENV_PATH"
    virtualenv "$VENV_PATH"
    source "${VENV_PATH}/bin/activate"
        pip install -r "${TRSYNC_DIR}/requirements.txt"
        pushd "${TRSYNC_DIR}" &>/dev/null
            python setup.py build
            python setup.py install
        popd &>/dev/null
    deactivate
fi

[ -n "$VENV_PATH" ] && source "${VENV_PATH}/bin/activate"

which trsync &>/dev/null || exit_with_error "Can't find trsync"
TRSYNC_BIN=$(which trsync)
#
########################################################

########################################################
#
# Initialize local variables
#
[ -z "$SRCURI" ] && exit_with_error "Source URI is not defined"
[ -z "$SRCPATHS" ] && exit_with_error "Source paths is not defined"
[ -z "$HOSTS_TO_SYNC" ] && exit_with_error "Hosts to sync are not defined"

[ -z  "$REPOCACHE_DIR" ] && REPOCACHE_DIR=${WRK_DIR}/data
TIMESTAMP=$(date "+%Y-%m-%d-%H%M%S")
SNAPSHOT_DIR=snapshots

# Expand wildcards in SRCPATHS
for SRCPATH in $SRCPATHS; do
    rsync_params='-r'
    # Built-in search-replace is not applicable here
    # shellcheck disable=SC2001
    grep_pattern=$(echo "$SRCPATH" | sed 's|*|[^/]*|g; s|^/||')
    IFS='/' read -ra FOLDERS <<< "${SRCPATH%/}"
    unset dirs
    for folder in "${FOLDERS[@]}"; do
        dirs="$dirs/$folder"
        rsync_params="$rsync_params --include '$dirs'"
    done
    rsync_params="$rsync_params --exclude '*'"
    paths=$(bash -c "rsync $rsync_params $SRCURI")
    paths=$(echo "$paths" | grep -Eo "$grep_pattern")
    for path in $paths; do
        EXPANDED_SRCPATHS="$EXPANDED_SRCPATHS $path"
    done
done

failedmessage=""
for SRCPATH in $EXPANDED_SRCPATHS; do
    SYNCPATH=${SRCPATH}

    DSTPATH=${REPOCACHE_DIR}/${SRCPATH}
    LOCKFILE=${DSTPATH//\//_}.lock
    TMP_DIR=${DSTPATH}.tmp
    rm -rf "${TMP_DIR}" "${TMP_DIR}.chksum"
    mkdir -p "${DSTPATH}" "${TMP_DIR}"
    # Dereference symlinks if necessary
    if ! rsync -l "${SRCURI}/${SRCPATH}" &>/dev/null ; then
        failedmessage="${failedmessage}
FAILED PATH: ${SYNCPATH}"
        continue
    fi
    srcinfo=$(rsync -l "${SRCURI}/${SRCPATH}")
    [ "${srcinfo:0:1}" == "l" ] && SRCPATH=${SRCPATH%/*}/${srcinfo##* }
    #
    ########################################################

    # Lock working directory to aviod race conditions
    job_lock "${LOCKFILE}" set

        ########################################################
        #
        # Get new repository state
        #
        rsync -avPzt --link-dest "${DSTPATH}/" "${SRCURI}/${SRCPATH}/*" "${TMP_DIR}"

        ########################################################
        #
        # Calculate checksum of the new repository state
        #
        metadata=$(find "${TMP_DIR}" -name repomd.xml -o -name Release | sort -u)
        checksum=""
        for file in $metadata ; do
            checksum=${checksum}$(sha1sum "${file}" | awk '{print $1}')
        done
        echo "${checksum}" > "${TMP_DIR}.chksum"
        ########################################################
        #
        # Detect changes of the repository and sync new
        # repository state to the hosts
        #
        [ "$FORCE" == "true" ] && rm -f "${DSTPATH}.chksum"
        if ! diff -N -q "${TMP_DIR}.chksum" "${DSTPATH}.chksum" &>/dev/null ; then
            rm -rf "${DSTPATH}" "${DSTPATH}.chksum"
            mv "${TMP_DIR}" "${DSTPATH}"
            mv "${TMP_DIR}.chksum" "${DSTPATH}.chksum"
            failedhosts=""
            if [ "$UPDATE_HEAD_SYMLINK" = "true" ] ; then
                UPDATE_HEAD_PARAM="-s ${DSTPATH##*/}"
            else
                unset UPDATE_HEAD_PARAM
            fi
            # Double quoting breaks bash quoting at UPDATE_HEAD_PARAM
            # shellcheck disable=SC2086
            for host in $HOSTS_TO_SYNC ; do
                if ! ${TRSYNC_BIN} push "${DSTPATH}" "${SYNCPATH##*/}" \
                    -d "${host}/${SYNCPATH%/*}" \
                    $UPDATE_HEAD_PARAM \
                    --init-directory-structure \
                    --snapshot-dir "$SNAPSHOT_DIR" \
                    --timestamp "$TIMESTAMP"
                then
                    rm -f "${DSTPATH}.chksum"
                    failedhosts="${failedhosts} ${host}"
                fi
            done
        fi
        #
        ########################################################

    job_lock "${LOCKFILE}" unset

    ########################################################
    #
    # Cleanup temporary data
    #
    rm -rf "${TMP_DIR}" "${TMP_DIR}.chksum"

    [ -n "$failedhosts" ] && failedmessage="${failedmessage}
FAILED PATH: ${SYNCPATH}
FAILED HOSTS: ${failedhosts}"
done

########################################################
#
# Uninitialize trsync and exit
#
[ -n "$VENV_PATH" ] && deactivate

[ -n "$failedmessage" ] && exit_with_error "$failedmessage"

exit 0
