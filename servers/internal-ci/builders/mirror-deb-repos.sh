#!/bin/bash
set -ex

########################################################
#
# Used variables
#
# HOSTS_TO_SYNC : space separated list of locations to
#                 sync to
#                 e.g. `rsync://host/module/path/to /srv/mirror`
# MIRROR_LIST   : space separated list of mirrors like
#   `[path]|[remote host]|[remote root]|[dist list]|[suite list]|[arch list]|[download method]{|[rsync module]}'
#
# TRSYNC_SCM          : source project of trsync
# TRSYNC_SCM_BRANCH   : trsync branch to use
# TRSYNC_DIR          : local path to trsync project
# MIRRORS_DIR         : path to debmirror mirrors folder

# SNAPSHOT_DIR        : optional; default is `.snapshots`
# SNAPSHOT_LIFETIME   : optional; default is 61
# FORCE               : bool; create new snapshots even
#                       if there are no new changes
# UPDATE_HEAD_SYMLINK : bool;
#
# Requirements:
#     Packages: python-virtualenv
#               python-pip
#               xz-utils
#               debmirror
#
#     Other: trsync source cloned into TRSYNC_DIR
#

########################################################
#
# Initialize local variables
#
MIRRORS_DIR=${MIRRORS_DIR:-/srv/aptly/mirrors}

TRSYNC_SCM=${TRSYNC_SCM:-'https://review.fuel-infra.org/infra/trsync'}
TRSYNC_SCM_BRANCH=${TRSYNC_SCM_BRANCH:-'stable/0.9'}
TIMESTAMP=$(date "+%Y-%m-%d-%H%M%S")
SNAPSHOT_DIR=${SNAPSHOT_DIR:-snapshots}
TRSYNC_DIR=${TRSYNC_DIR:-${HOME}/trsync}
UPDATE_HEAD_SYMLINK=${UPDATE_HEAD_SYMLINK:-true}
SNAPSHOT_LIFETIME=${SNAPSHOT_LIFETIME:-61}
HOSTS_TO_SYNC=${HOSTS_TO_SYNC:-/srv/aptly/public}
#
########################################################

exit_with_error() {
    >&2 echo "$@"
    exit 1
}

job_lock() {
    [ -z "$1" ] && exit_with_error "Lock file is not specified"
    local LOCKFILE=$1
    shift
    fd=15
    eval "exec ${fd}>${LOCKFILE}"
    case $1 in
        "set")
            flock -x -n ${fd} \
                || exit_with_error "Process already running. Lockfile: ${LOCKFILE}"
            ;;
        "unset")
            flock -u ${fd}
            ;;
        "wait")
            TIMEOUT=${2:-3600}
            echo "Waiting of concurrent process (lockfile: ${LOCKFILE}, timeout = ${TIMEOUT} seconds) ..."
            if flock -x -w "${TIMEOUT}" ${fd} ; then
                echo DONE
            else
                exit_with_error "Timeout error (lockfile: ${LOCKFILE})"
            fi
            ;;
    esac
}

download_repo() {
    # params:
    # $1 dest folder name inside $MIRRORS_DIR
    # $2 remote host
    # $3 path to repo on remote host
    # $4 comma separated list of distributions
    # $5 comma separated list of sections (suites)
    # $6 comma separated list of architectures
    # $7 download method
    # $8 rsync module (optional)

    # convert `|` delimited params into positional args
    eval set -- "${1//|/ }"

    local mirrorDir=$1
    local remoteHost=$2
    local remoteRoot=$3
    local dists=$4
    local sections=$5
    local arches=$6
    local method=$7
    local module=$8

    debmirror \
        --verbose \
        --nosource \
        --ignore-release-gpg \
        --no-check-gpg \
        --timeout 300 \
        --rsync-batch 200 \
        --rsync-options "-aIL --partial --force --no-motd" \
        --rsync-extra indices,trace \
        --method "${method}" \
        --host "${remoteHost}" \
        --root "${module}${remoteRoot}" \
        --dist "${dists}" \
        --section "${sections}" \
        --arch "${arches}" \
        "${MIRRORS_DIR}/${mirrorDir}"
}

export LANG=C

########################################################
#
# Initialize trsync
#
if [ ! -d "${TRSYNC_DIR}" ] ; then
    mkdir -p "${TRSYNC_DIR}"
    git clone "${TRSYNC_SCM}" "${TRSYNC_DIR}"
    pushd "${TRSYNC_DIR}" &>/dev/null
    git checkout "${TRSYNC_SCM_BRANCH}"
    popd &>/dev/null
fi

VENV_PATH=${TRSYNC_DIR}/.venv

if [ ! -d "${VENV_PATH}" ] ; then
    mkdir -p "${VENV_PATH}"
    virtualenv "${VENV_PATH}"
    source "${VENV_PATH}/bin/activate"
        pip install -r "${TRSYNC_DIR}/requirements.txt"
        pushd "${TRSYNC_DIR}" &>/dev/null
            python setup.py build
            python setup.py install
        popd &>/dev/null
    deactivate
fi

[ -n "${VENV_PATH}" ] && source "${VENV_PATH}/bin/activate"

which trsync &>/dev/null || exit_with_error "Can't find trsync"
TRSYNC_BIN=$(which trsync)
#
########################################################

failedmessage=""

for mirror in ${MIRROR_LIST}; do

    mirrorName=${mirror%%|*}
    mirrorDir=${MIRRORS_DIR}/${mirrorName}
    mkdir -p "${mirrorDir}"

    mirrorChksum=${mirrorDir}.chksum

    LOCKFILE=${mirrorDir}.lock

    # Lock working directory to aviod race conditions
    job_lock "${LOCKFILE}" set

        ########################################################
        #
        # Get new repository state
        #
        if ! download_repo "${mirror}" ; then
            failedmessage="${failedmessage}
FAILED MIRROR: ${mirror}"
            continue
        fi

        ########################################################
        #
        # Calculate checksum of the new repository state
        #
        metadata=$(find "${mirrorDir}" -name repomd.xml -o -name Release | sort -u)
        checksum=""
        for file in ${metadata} ; do
            checksum=${checksum}$(sha1sum "${file}" | awk '{print $1}')
        done
        echo "${checksum}" > "${mirrorChksum}.new"
        ########################################################
        #
        # Detect changes of the repository and sync new
        # repository state to the hosts
        #
        [ "${FORCE}" == "true" ] && rm -f "${mirrorChksum}"
        if ! diff -N -q "${mirrorChksum}" "${mirrorChksum}.new" &>/dev/null ; then
            # Split mirrorName into Prefix and Name
            _mirrorName=${mirrorName##*/}
            _mirrorNamePrefix=${mirrorName%${_mirrorName}}
            mv "${mirrorChksum}.new" "${mirrorChksum}"
            failedhosts=""
            if [ "${UPDATE_HEAD_SYMLINK}" = "true" ] ; then
                UPDATE_HEAD_PARAM="-s ${_mirrorName}"
            else
                unset UPDATE_HEAD_PARAM
            fi
            # Double quoting breaks bash quoting at UPDATE_HEAD_PARAM
            # shellcheck disable=SC2086
            # TODO: Make UPDATE_HEAD_PARAM transactional over all hosts
            for host in ${HOSTS_TO_SYNC} ; do
                # For local destination create `latest` symlink to
                # source in order to avoid data duplication
                if [ "${host:0:1}" == "/" \
                    -a ! -e "${host}/${_mirrorNamePrefix}${SNAPSHOT_DIR}/${_mirrorName}-latest" ] ; then
                    mkdir -p "${host}/${_mirrorNamePrefix}${SNAPSHOT_DIR}"
                    ln -s "${mirrorDir}" \
                          "${host}/${_mirrorNamePrefix}${SNAPSHOT_DIR}/${_mirrorName}-latest"
                fi
                if ! ${TRSYNC_BIN} push "${mirrorDir}" "${_mirrorName}" \
                    -d "${host}/${_mirrorNamePrefix}" \
                    ${UPDATE_HEAD_PARAM} \
                    --snapshot-lifetime "${SNAPSHOT_LIFETIME}" \
                    --init-directory-structure \
                    --snapshot-dir "${SNAPSHOT_DIR}" \
                    --extra '\--exclude /project/ \--exclude /.temp/' \
                    --timestamp "${TIMESTAMP}"
                then
                    rm -f "${mirrorChksum}"
                    failedhosts="${failedhosts} ${host}"
                fi
            done
        fi
        #
        ########################################################

    job_lock "${LOCKFILE}" unset

    [ -n "${failedhosts}" ] && failedmessage="${failedmessage}
FAILED PATH: ${mirror}
FAILED HOSTS: ${failedhosts}"
done

########################################################
#
# Uninitialize trsync and exit
#
[ -n "${VENV_PATH}" ] && deactivate

[ -n "${failedmessage}" ] && exit_with_error "${failedmessage}"

exit 0
