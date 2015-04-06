#!/bin/bash -ex

##
## Vote for CR
##
vote() {
  ssh -p $GERRIT_PORT ${GERRIT_USER}@$GERRIT_HOST "$GERRIT_CMD"
}

source setenvfile
[ -n "$GERRIT_REVIEWER" ] && GERRIT_USER=$GERRIT_REVIEWER
rm -f setenvfile

if [ $RESULT -eq 0 ]; then
    VOTE=$GERRIT_VOTE
    GERRIT_RESULT="SUCCESS"
else
    VOTE="-"$GERRIT_VOTE
    GERRIT_RESULT="FAILURE"
fi
[ "$SKIPPED" == "1" ] && GERRIT_RESULT=${GERRIT_RESULT}" (skipped)" && VOTE=0
GERRIT_MESSAGE="* $JOB_NAME $BUILD_URL : $GERRIT_RESULT"
[ -n "$TIME_ELAPSED" ] && GERRIT_MESSAGE="$GERRIT_MESSAGE in $TIME_ELAPSED"
# Add repository link to gerrit comment"
if [ $RESULT -eq 0 ] && [ -f "project.envfile" ] ; then
    source project.envfile
    REPOURL=`echo $OBSAPI | awk -F'[/:]' '{print $4}'`
    REPOURL="http://${REPOURL}:82/${PROJECTNAME}/${REPONAME}"
    GERRIT_MESSAGE="${GERRIT_MESSAGE}
* package.repository $REPOURL : LINK"
fi

GERRIT_CMD=gerrit\ review\ $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER\ \'--message="$GERRIT_MESSAGE"\'\ --verified\ ${VOTE}
echo $GERRIT_MESSAGE

TRIES=5
while true; do
  [ "$TRIES" == "0" ] && exit 1
  vote && break
  ((--TRIES)) || :
  sleep 5
done

[ $RESULT -ne 0 ] && exit 1 || :
