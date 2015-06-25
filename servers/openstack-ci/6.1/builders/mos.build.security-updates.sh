#!/bin/bash -ex
[ -z "$SECUPDATETAG" ] && SECUPDATETAG="^Security-update"
source setenvfile
[ "$RESULT" != "0" ] && exit 0
[ -z "$GERRIT_PROJECT" ] && exit 0
[ "$UPDATES" != "true" ] && exit 0
[ ! -f "project.envfile" ] && exit 0
[ $(echo "$GERRIT_CHANGE_COMMIT_MESSAGE" | base64 -d | grep -c "$SECUPDATETAG") -eq 0 ] && exit 0

source project.envfile

PACKAGES=$(osc $OBSAPI api /build/$PROJECTNAME/$REPONAME/$ARCH/$PACKAGENAME | grep "binary filename" | cut -d'"' -f2 | egrep -v "_(buildenv|statistics)$" | tr '\n' ' ')
OBSSERVER=`echo "$OBSAPI" | cut -d'/' -f3 | cut -d':' -f1`
ssh $OBSSERVER "bash -ex update-security-updates.sh $PROJECTNAME $REPONAME $PACKAGES"
