#!/bin/bash

set -o xtrace
set -o errexit

##
## Vote for CR
##
vote() {
  if [ "$NO_VOTE" != "true" ] ; then
      # Debug mode:
      # ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" gerrit ls-projects >/dev/null
      # echo ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" "${GERRIT_CMD}"
      # shellcheck disable=SC2029
      ssh -p "${GERRIT_PORT}" "${GERRIT_USER}@${GERRIT_HOST}" "${GERRIT_CMD}"
  fi
}

source setenvfile
[ -n "${GERRIT_REVIEWER}" ] && GERRIT_USER=${GERRIT_REVIEWER}
[ -n "${GERRIT_INSTALL_VOTE}" ] && GERRIT_VOTE=${GERRIT_INSTALL_VOTE}
[ -n "${GERRIT_DEPLOY_VOTE}" ] && GERRIT_VOTE=${GERRIT_DEPLOY_VOTE}

# Do not perform voting if gerrit request is not defined
[ -z "${GERRIT_CHANGE_NUMBER}" ] && exit "${RESULT}"

if [ "${RESULT}" == 0 ]; then
    VOTE="--verified $GERRIT_VOTE"
    GERRIT_RESULT="SUCCESS"
else
    VOTE="--verified -$GERRIT_VOTE"
    GERRIT_RESULT="FAILURE"
fi
[ "${SKIP_VOTE}" -eq 1 ] && GERRIT_RESULT=${GERRIT_RESULT}" (skipped)" && unset VOTE
GERRIT_MESSAGE="* ${DIST}:${JOB_NAME} ${BUILD_URL} : ${GERRIT_RESULT}"
[ -n "${TIME_ELAPSED}" ] && GERRIT_MESSAGE="${GERRIT_MESSAGE} in ${TIME_ELAPSED}"
# Add repository link to gerrit comment"
if [ -f "buildresult.params" ] ; then
    source buildresult.params
    PUBLISH_SETENV=${DIST}.publish.setenvfile
    [ -f "$PUBLISH_SETENV" ] && source "$PUBLISH_SETENV"

    if [ "${RESULT}" == 0 ] ; then
        # Clean up repo url string
        _repo_url=${REPO_URL//\"}
        GERRIT_MESSAGE="${GERRIT_MESSAGE}
* package.repository ${_repo_url%% *} : LINK"
    fi
fi

GERRIT_CMD="gerrit review ${GERRIT_CHANGE_NUMBER},${GERRIT_PATCHSET_NUMBER} '--message=${GERRIT_MESSAGE}' ${VOTE}"

TRIES=5
while true; do
  [ "${TRIES}" == 0 ] && exit 1
  vote && break
  (( TRIES-- ))
  sleep 5
done
