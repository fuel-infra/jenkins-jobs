#!/bin/bash
set -ex

########################################################
#
# This script run trsync utility for create symbolic link
# on mirror.fuel-infra.org
#
# Used variables
#
# HOSTS         : host list sync to
#               : E.g. "rsync://seed-cz1.fuel-infra.org \
#               :      rsync://seed-us1.fuel-infra.org"
#
# SYMLINK       : name of symlink that need be created
#
# TARGET        : snapshot name's on which should redirect SYMLINK
#
# DIRECT_TARGET : full path to snapshot name's on which should redirect SYMLINK
#                 exclude hostname
#
# TRSYNC_DIR    : local path to trsync project
#

function exit_with_message() {
    >&2 echo "$1"
    exit "$2"
}

export LANG=C
WRK_DIR=$(pwd)

########################################################
# Initialize trsync
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

which trsync &>/dev/null || exit_with_message "Can't find trsync" 1
TRSYNC_BIN=$(which trsync)
#
########################################################

########################################################
# Initialize local variables

# String with additional rsync parameters
unset EXTRA
[ "$DRY_RUN" == "true" ] && EXTRA="--extra \"\--dry-run\""

[ -z "$HOSTS" ] && exit_with_message "Hosts to create symlink are not defined" 1

PATH_TO_SYMLINK="mirror-sync/${ROOT_DIR_TARGET}"
########################################################
# Create symlink
FAILEDHOST=""
for HOST in ${HOSTS}; do
    if ! bash -c "${TRSYNC_BIN} symlink -d ${HOST}/${PATH_TO_SYMLINK} -s ${SYMLINK} -t ${TARGET} --update ${EXTRA}" ; then
        FAILEDHOST="${FAILEDHOST} ${HOST}"
    fi
done
#
########################################################

########################################################
#
# Uninitialize trsync and exit
#
[ -n "$VENV_PATH" ] && deactivate

[ -n "$FAILEDHOST" ] && exit_with_message "On the following hosts symlinks weren't updated:${FAILEDHOST}" 1

exit 0
