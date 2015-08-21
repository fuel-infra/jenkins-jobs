#!/bin/bash

set -o xtrace
set -o errexit
set -o pipefail

START_TS=$(date +%s)

# Remove quotes, double and trailing slashes
REPO_URL=$(echo "${REPO_URL}" | sed 's|"||g; s|/\+|/|g; s|:|:/|g; s|/ | |g')
EXTRAREPO=$(echo "${EXTRAREPO}" | sed 's|"||g; s|/\+|/|g; s|:|:/|g; s|/ | |g')
PACKAGELIST=$(echo "${PACKAGELIST}" | sed 's|,| |g')

echo FAILED=false >> ci_status_params
RESULT=0
for script in version-test-rpm vm-test repo-test-rpm
do
    if [ -x "${WORKSPACE}/${script}" ]
    then
        if ! bash -x "${WORKSPACE}/${script}"
        then
            sed -i 's/FAILED=false/FAILED=true/' ci_status_params
            RESULT=1
        fi
    fi
done

TIME_ELAPSED=$(( $(date +%s) - ${START_TS} ))
echo "RESULT=${RESULT}" > setenvfile
echo "TIME_ELAPSED='$(date -u -d @${TIME_ELAPSED} +'%Hh %Mm %Ss' | sed 's|^00h ||; s|^00m ||')'" >> setenvfile
