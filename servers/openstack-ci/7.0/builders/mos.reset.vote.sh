#!/bin/bash

set -o xtrace
set -o errexit

##
## Reset previous vote
##
vote() {
  ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" "${GERRIT_CMD}"
}

# Do not perform voting if gerrit request is not defined
[ -z "${GERRIT_CHANGE_NUMBER}" ] && exit 0

[ -n "${GERRIT_REVIEWER}" ] && GERRIT_USER=${GERRIT_REVIEWER}
GERRIT_MESSAGE="* ${JOB_NAME} ${BUILD_URL} : STARTED"
GERRIT_CMD="gerrit review ${GERRIT_CHANGE_NUMBER},${GERRIT_PATCHSET_NUMBER} '--message=${GERRIT_MESSAGE}' --verified 0"

TRIES=5
while true; do
  [ "${TRIES}" == 0 ] && exit 1
  vote && break
  (( TRIES-- ))
  sleep 5
done

##
## Reset vote for corresponding CR
##
[ -f corr.setenvfile ] && source corr.setenvfile
if [ -n "${CORR_CHANGE_NUMBER}" ] ; then
    GERRIT_CMD="gerrit review ${CORR_CHANGE_NUMBER},${CORR_PATCHSET_NUMBER} '--message=${GERRIT_MESSAGE}' --verified 0"
    TRIES=5
    while true; do
        [ "${TRIES}" == 0 ] && exit 1
        vote && break
        (( TRIES-- ))
        sleep 5
    done
fi

exit 0
