#!/bin/bash -ex

##
## Reset previous vote
##
vote() {
  ssh -p $GERRIT_PORT ${GERRIT_USER}@$GERRIT_HOST "$GERRIT_CMD"
}

[ -n "$GERRIT_REVIEWER" ] && GERRIT_USER=$GERRIT_REVIEWER
GERRIT_MESSAGE="* $JOB_NAME $BUILD_URL : STARTED"
GERRIT_CMD=gerrit\ review\ $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER\ \'--message="$GERRIT_MESSAGE"\'\ --verified\ 0

TRIES=5
while true; do
  [ "$TRIES" == "0" ] && exit 1
  vote && break
  ((--TRIES)) || :
  sleep 5
done
