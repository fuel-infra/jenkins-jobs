#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail

START_TS=$(date +%s)

# Remove quotes, double and trailing slashes
# shellcheck disable=SC2001
REPO_URL=$(echo "${REPO_URL}" | sed 's|"||g; s|/\+|/|g; s|:|:/|g; s|/ | |g')
# shellcheck disable=SC2001
EXTRAREPO=$(echo "${EXTRAREPO}" | sed 's|"||g; s|/\+|/|g; s|:|:/|g; s|/ | |g')
echo "PACKAGENAME=${DIST}:${GERRIT_PROJECT##*/}"

#CR_REMOTE=$(git remote -v | head -1 | awk '{print $2}')
#CR_USER=$(echo $CR_REMOTE | awk -F'[:@/]' '{print $4}')
#CR_HOST=$(echo $CR_REMOTE | awk -F'[:@/]' '{print $5}')
#CR_PORT=$(echo $CR_REMOTE | awk -F'[:@/]' '{print $6}')
#CRS='20981'
#for cr in $CRS ; do
#    CR_REF=$(ssh ${CR_USER}@${CR_HOST} -p ${CR_PORT} \
#        gerrit query --current-patch-set $cr | fgrep "ref:" | awk '{print $2}')
#    git fetch ${CR_REMOTE} ${CR_REF} && git cherry-pick FETCH_HEAD
#done

RESULT=0

#for script in "version-test-${REPO_TYPE}" vm-test "repo-test-${REPO_TYPE}"
for script in "version-test-${REPO_TYPE}" vm-test
do
    if [ -x "${WORKSPACE}/${script}" ]
    then
        if ! bash -x "${WORKSPACE}/${script}"
        then
            RESULT=1
        fi
    fi
done

TIME_ELAPSED=$(( $(date +%s) - START_TS ))
echo "RESULT=${RESULT}" > setenvfile
echo "TIME_ELAPSED='$(date -u -d @${TIME_ELAPSED} +'%Hh %Mm %Ss' | sed 's|^00h ||; s|^00m ||')'" >> setenvfile
