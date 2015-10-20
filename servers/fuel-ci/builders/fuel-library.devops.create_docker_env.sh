#!/bin/bash

set -ex

# Checking gerrit commits for fuel-main
if [ "${fuelmain_gerrit_commit}" != "none" ] ; then
  for commit in ${fuelmain_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-main "${commit}" && git cherry-pick FETCH_HEAD || false
  done
fi

MIRROR=http://mirror.fuel-infra.org
LATEST_TARGET=$(curl -sSf "${MIRROR}/mos-repos/centos/mos8.0-centos6-fuel/os.target.txt" | head -1)
# use mirror from snapshot
export CENTOS_MIRROR="${MIRROR}/mos-repos/centos/mos8.0-centos6-fuel/${LATEST_TARGET}/x86_64/"

# must be defined directly, otherwise script will save to /var/tmp
export ARTS_DIR="${WORKSPACE}/artifacts"

rm -rf "${ARTS_DIR}"
mkdir "${ARTS_DIR}"

# prepare env for buidling rpm packages
"${WORKSPACE}"/utils/build_fuel_packages/docker/create_rpmbuild_env.sh

# prepare env for buidling deb packages
"${WORKSPACE}"/utils/build_fuel_packages/docker/create_debbuild_env.sh
