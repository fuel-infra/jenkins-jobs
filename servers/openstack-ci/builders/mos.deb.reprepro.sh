#!/bin/bash -ex
source setenvfile
[ "$RESULT" != "0" ] && exit 0
[ -z "$GERRIT_PROJECT" ] && exit 0
[ ! -f "project.envfile" ] && exit 0

source project.envfile

#PACKAGES=`osc $OBSAPI api /build/$PROJECTNAME/$REPONAME/$ARCH/$PACKAGENAME | grep "binary filename" | cut -d'"' -f2 | tr '\n' ' '`
OBSSERVER=`echo "$OBSAPI" | cut -d'/' -f3 | cut -d':' -f1`
ssh $OBSSERVER "bash -ex update-reprepro-updates.sh $PROJECTNAME"
