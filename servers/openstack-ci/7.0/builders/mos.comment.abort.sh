#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail

function retry {
    local count=$1; shift
    local ec
    while [[ "$count" -gt 0 && "$ec" != 0 ]]
    do
        eval "$@" && true
        ec=$?
        sleep 5
        ((count--))
    done
    return "$ec"
}

function gerrit_command {
  ssh -p "$GERRIT_PORT" "${GERRIT_USER}@${GERRIT_HOST}" "$GERRIT_CMD"
}

if curl -sS "$UPSTREAM_BUILD_URL/consoleText" | grep -q '^Build was aborted'
then
    GERRIT_MESSAGE="* $UPSTREAM_JOB_NAME $UPSTREAM_BUILD_URL : ABORTED"
    GERRIT_CMD="gerrit review $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER --message '$GERRIT_MESSAGE'"
    retry 5 gerrit_command
fi
