#!/bin/bash
#
#   :mod:`rm-old-workspaces.sh` -- Remove obsolteted job workspaces
#   ==========================================
#
#   .. module:: rm-old-workspaces.sh
#       :platform: Unix, Windows
#       :synopsis: Removes job worspaces older than some configured value
#   .. vesionadded:: MOS-9.0
#   .. author:: Alexander Evseev <aevseev@mirantis.com>
#
#
#   .. envvar::
#       :var  JOB_AGE: Age of job workspace to be deleted (days), defaults to ``30``
#       :type JOB_AGE: int
#       :var  JOB_DIR_SKIPLIST: Comma and/or space separated list of non-removable dirs
#       :type JOB_DIR_SKIPLIST: string
#       :type JOB_AGE: int
#       :var  WORKSPACE: Location where build is started, defaults to ``.``
#       :type WORKSPACE: path
#
#
#   .. entrypoint:: main
#
#
#   .. affects::
#       :dir ~/workspace/: job workspaces

set -ex

declare -a SKIP_LIST
declare -a DIRNAME_FILTER

JOB_AGE="${JOB_AGE:-30}"
JOB_DIR_SKIPLIST="${JOB_DIR_SKIPLIST:-}"
WORKSPACE="${WORKSPACE:-.}"

# ${WORKSPACE} contains a path to the _JOB_ workspace, not ~/workspace/
# Get parent directory
WORKSPACE=$(dirname "$WORKSPACE")

main () {
    #   .. function:: main
    #
    #       Finds directories in ${WORKSPACE} older than ${JOB_AGE} days
    #       and removes it skipping those that listed in ${JOB_DIR_SKIPLIST}
    #
    #       :stdin: not used
    #       :stdout: useless debug information
    #       :stderr: not used
    #

    local OLDIFS=$IFS
    IFS=" ,"
    SKIP_LIST=( $JOB_DIR_SKIPLIST )
    IFS=$OLDIFS

    for DIRNAME in "${SKIP_LIST[@]}"; do
        DIRNAME_FILTER+=( "!" "-name" "$DIRNAME" )
    done

    find "$WORKSPACE" -maxdepth 1 -type d -ctime "+${JOB_AGE}" "${DIRNAME_FILTER[@]}" \
    | while read -r JOB_DIR; do
        echo "Removing obsolete job directory: ${JOB_DIR}"
        rm -rf "$JOB_DIR"
    done
}

if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
    main "$@"
fi
