#!/bin/bash

set -o xtrace
set -o errexit

##
## Vote for CR
##
vote() {
  ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" "${GERRIT_CMD}"
}

source setenvfile
[ -n "${GERRIT_REVIEWER}" ] && GERRIT_USER=${GERRIT_REVIEWER}
[ -n "${GERRIT_INSTALL_VOTE}" ] && GERRIT_VOTE=${GERRIT_INSTALL_VOTE}
[ -n "${GERRIT_DEPLOY_VOTE}" ] && GERRIT_VOTE=${GERRIT_DEPLOY_VOTE}
rm -f setenvfile

# Do not perform voting if gerrit request is not defined
[ -z "${GERRIT_CHANGE_NUMBER}" ] && exit "${RESULT}"

if [ "${RESULT}" == 0 ]; then
    VOTE=${GERRIT_VOTE}
    GERRIT_RESULT="SUCCESS"
else
    VOTE="-"${GERRIT_VOTE}
    GERRIT_RESULT="FAILURE"
fi
[ "${SKIPPED}" == 1 ] && GERRIT_RESULT=${GERRIT_RESULT}" (skipped)" && VOTE=0
GERRIT_MESSAGE="* ${JOB_NAME} ${BUILD_URL} : ${GERRIT_RESULT}"
[ -n "${TIME_ELAPSED}" ] && GERRIT_MESSAGE="${GERRIT_MESSAGE} in ${TIME_ELAPSED}"
# Add repository link to gerrit comment"
[ -f "buildresult.params" ] && source buildresult.params
case "${REPO_TYPE}" in
    deb)
        [ -f "deb.publish.setenvfile" ] && source deb.publish.setenvfile
        REPOURL=${DEB_REPO_URL%% *}
        ;;
    rpm)
        [ -f "rpm.publish.setenvfile" ] && source rpm.publish.setenvfile
        REPOURL=${RPM_REPO_URL}
        ;;
esac

[ "${RESULT}" == 0 ] && [ -n "${REPOURL}" ] \
    && GERRIT_MESSAGE="${GERRIT_MESSAGE}
* package.repository ${REPOURL} : LINK"

GERRIT_CMD="gerrit review ${GERRIT_CHANGE_NUMBER},${GERRIT_PATCHSET_NUMBER} '--message=${GERRIT_MESSAGE}' --verified ${VOTE}"

TRIES=5
while true; do
  [ "${TRIES}" == 0 ] && exit 1
  vote && break
  (( TRIES-- ))
  sleep 5
done

##
## Vote for corresponding CR
##
[ -f corr.setenvfile ] && source corr.setenvfile
if [ -n "${CORR_CHANGE_NUMBER}" ] ; then
    GERRIT_CMD="gerrit review ${CORR_CHANGE_NUMBER},${CORR_PATCHSET_NUMBER} '--message=${GERRIT_MESSAGE}' --verified ${VOTE}"
    TRIES=5
    while true; do
        [ "${TRIES}" == 0 ] && exit 1
        vote && break
        (( TRIES-- ))
        sleep 5
    done
fi

exit "${RESULT}"
