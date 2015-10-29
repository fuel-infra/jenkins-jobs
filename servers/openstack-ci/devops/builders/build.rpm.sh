#!/bin/bash

set -o xtrace
set -o errexit

[ -z "${GERRIT_HOST}" ] && export GERRIT_HOST='review.fuel-infra.org'

for logfile in buildlog.txt rootlog.txt buildresult.xml no-vote.tmp setenvfile; do
    [ -f "${logfile}" ] && rm -f "${logfile}"
done

START_TS=$(date +%s)
if bash build-mixed-rpm.sh; then
  RESULT=0
else
  [ -f "no-vote.tmp" ] && echo "NO_VOTE=true" > setenvfile
  rm -f no-vote.tmp
  RESULT=1
fi
TIME_ELAPSED=$(( $(date +%s) - ${START_TS} ))
echo "RESULT=${RESULT}" >> setenvfile
echo "TIME_ELAPSED='$(date -u -d @${TIME_ELAPSED} +'%Hh %Mm %Ss' | sed 's|^00h ||; s|^00m ||')'" >> setenvfile
