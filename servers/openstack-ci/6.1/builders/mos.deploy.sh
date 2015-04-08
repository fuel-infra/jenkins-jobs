#!/bin/bash -ex

START_TS=$(date +%s)
export TEST_JOB=true

case "${GERRIT_PROJECT##*/}" in
    murano|murano-build)
        export SLAVE_NODE_MEMORY=6144
        export KEEP_BEFORE=no
        ;;
esac

if bash -ex package-testing; then
  echo FAILED=false >> ci_status_params
  RESULT=0
else
  echo FAILED=true >> ci_status_params
  RESULT=1
fi

TIME_ELAPSED=$(( $(date +%s) - START_TS ))
echo "RESULT=$RESULT" > setenvfile
echo "TIME_ELAPSED='`date -u -d @$TIME_ELAPSED +'%Hh %Mm %Ss' | sed 's|^00h ||; s|^00m ||'`'" >> setenvfile
