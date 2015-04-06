#!/bin/bash
if [[ "`echo $GERRIT_PROJECT | rev | cut -d"/" -f1 | rev`" == "murano-apps" ]] ; then exit 0 ; fi

START_TS=$(date +%s)
if bash -ex test-source.sh; then
  RESULT=0
else
  RESULT=1
fi
TIME_ELAPSED=$(( $(date +%s) - START_TS ))
echo "RESULT=$RESULT" > setenvfile
echo "TIME_ELAPSED='`date -u -d @$TIME_ELAPSED +'%Hh %Mm %Ss' | sed 's|^00h ||; s|^00m ||'`'" >> setenvfile
echo "SKIPPED=1" >> setenvfile
