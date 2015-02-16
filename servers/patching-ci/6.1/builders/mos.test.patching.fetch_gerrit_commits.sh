#!/bin/bash -x

set -o errexit
set -o errtrace
set -o pipefail

# Checking gerrit commits for patching-tests
if [[ "${patchingtests_gerrit_commit}" != "none" && -d "${WORKSPACE}/patching-tests/" ]]; then
   pushd "${WORKSPACE}/patching-tests/"
   for commit in ${patchingtests_gerrit_commit} ; do
       git fetch "https://review.fuel-infra.org/patching-tests" "${commit}" && git cherry-pick FETCH_HEAD
   done
   popd
fi

# Checking gerrit commits for fuel-qa
if [[ "${fuelqa_gerrit_commit}" != "none" && -d "${WORKSPACE}/fuel-qa/" ]]; then
   pushd "${WORKSPACE}/fuel-qa/"
   for commit in ${fuelqa_gerrit_commit} ; do
       git fetch "https://review.openstack.org/stackforge/fuel-qa" "${commit}" && git cherry-pick FETCH_HEAD
   done
   popd
fi
