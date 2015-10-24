#!/bin/bash

set -ex

WEB_SHARE_ROOT=/var/www/fwm/
WEB_SHARE_JOB="${WEB_SHARE_ROOT}/${JOB_NAME}/${BUILD_ID}"

export BUILD_DIR=${WORKSPACE}/../tmp/${JOB_NAME}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

export ARTS_DIR=${WORKSPACE}/artifacts
rm -rf "${ARTS_DIR}"

export DEPS_DIR=${BUILD_DIR}/deps
rm -rf "${DEPS_DIR}"

# Checking gerrit commits for fuel-main
if [ "${FUELMAIN_COMMIT}" != "stable/7.0" ] ; then
    git checkout "${FUELMAIN_COMMIT}"
fi

# Checking gerrit commits for fuel-main
if [ "${fuelmain_gerrit_commit}" != "none" ] ; then
  for commit in ${fuelmain_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-main "${commit}" && git cherry-pick FETCH_HEAD || false
  done
fi

# get upstream mirror
echo "${NOARTIFACT_MIRROR}"

if [ -z "${NOARTIFACT_MIRROR}" ]; then
  echo "EXTRA_RPM_REPOS=${EXTRA_RPM_REPOS}"
else
  EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS} noartifacts-proposed,${NOARTIFACT_MIRROR}/x86_64"
  echo "EXTRA_RPM_REPOS=${EXTRA_RPM_REPOS}"
fi

#########################################

echo "STEP 0. Clean before start"
make deep_clean

#########################################

echo "STEP 1. Make packages-late target"
make packages-late ${make_args}

#########################################

echo "STEP 2. Publish everything"

mkdir -p "${ARTS_DIR}"
echo FUELMAIN_GERRIT_COMMIT="${fuelmain_gerrit_commit}" > "${ARTS_DIR}/gerrit_commits.txt"

## copy artifacts to web-share folder
mkdir -p "${WEB_SHARE_JOB}"
find "${BUILD_DIR}/packages/rpm/RPMS/" -type f -name '*.rpm' -exec cp -v {} "${WEB_SHARE_JOB}" \;

# create artifact with links
rm -rf "${ARTS_DIR}/artifacts.txt"
find "${WEB_SHARE_JOB}" -name "*.rpm" -type f -printf "http://$(hostname)/fwm/${JOB_NAME}/${BUILD_ID}/%f\n" > "${ARTS_DIR}/artifacts.txt"

# copy urls to packages that were downloaded
cp -rv "${BUILD_DIR}/mirror/centos/urls.list" "${ARTS_DIR}/pkgs.list.txt"

# copy /home/jenkins/workspace/tmp/7.0-build.late.artifacts/build/docker/fuel-centos-build.log
cp -rv "${BUILD_DIR}/docker/fuel-centos-build.log" "${ARTS_DIR}/fuel-centos-build.log.txt"
