#!/bin/bash

set -o xtrace
set -o errexit

[ -z "${GERRIT_HOST}" ] && export GERRIT_HOST='review.fuel-infra.org'
echo "PACKAGENAME=${DIST}:${GERRIT_PROJECT##*/}"

for logfile in buildlog.txt rootlog.txt buildresult.xml no-vote.tmp setenvfile; do
    [ -f "${logfile}" ] && rm -f "${logfile}"
done

export EXTRAREPO=${EXTRAREPO//\"}

START_TS=$(date +%s)
case ${DIST_TYPE} in
    deb)
        script_name=build-mixed-deb.sh
        ;;
    rpm)
        script_name=build-mixed-rpm.sh
        ;;
    *)
        echo "Unsupported DIST_TYPE=${DIST_TYPE}"
        exit 1
        ;;
esac

if bash -x $script_name ; then
  RESULT=0
else
  [ -f "no-vote.tmp" ] && echo "NO_VOTE=true" > setenvfile
  rm -f no-vote.tmp
  RESULT=1
fi
TIME_ELAPSED=$(( $(date +%s) - START_TS ))
echo "RESULT=${RESULT}" >> setenvfile
echo "TIME_ELAPSED='$(date -u -d @${TIME_ELAPSED} +'%Hh %Mm %Ss' | sed 's|^00h ||; s|^00m ||')'" >> setenvfile
