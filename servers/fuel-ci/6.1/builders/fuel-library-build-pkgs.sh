#!/bin/bash

set -ex

if echo "${GERRIT_CHANGE_COMMIT_MESSAGE}" | grep -q -iE "Fuel-CI:\s+disable"; then
  echo "Fuel CI check disabled"
  exit -1
fi

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
rm -rf "${BUILD_DIR}"

export ARTS_DIR="${WORKSPACE}/packages"
rm -rf "${ARTS_DIR}"

cd fuel-main

# use commit from fuel-library in order to build library package
if [ "${GERRIT_REFSPEC}" !=  "refs/heads/master" ]; then
  export FUELLIB_GERRIT_COMMIT="${GERRIT_REFSPEC}"
fi

## Define packages related stuff
BUILD_RPM_PACKAGES="fuel-library6.1"
BUILD_DEB_PACKAGES="fuel-library6.1"

SOURCE_PATH="${BUILD_DIR}/packages/sources"
RPM_SPEC_PATH="${BUILD_DIR}/repos"
RPM_RESULT_DIR="${BUILD_DIR}/packages_rpm"
DEB_RESULT_DIR="${BUILD_DIR}/packages_deb"

rm -rf "${RPM_RESULT_DIR}" "${DEB_RESULT_DIR}"
mkdir -p "${RPM_RESULT_DIR}" "${DEB_RESULT_DIR}"

#########################################

echo "STEP 1. Make sources"

make sources -j8

#########################################

mkdir -p "${ARTS_DIR}"

echo FUELLIB_GERRIT_COMMIT="${FUELLIB_GERRIT_COMMIT}" >> "${ARTS_DIR}/gerrit_commits.txt"

cp -rv "${BUILD_DIR}/repos/version.yaml" "${ARTS_DIR}/version.yaml.txt"

# build rpm packages
for pkg in ${BUILD_RPM_PACKAGES}; do
  docker run --privileged --rm -v ${SOURCE_PATH}/${pkg}:/opt/sandbox/SOURCES \
           -v ${RPM_SPEC_PATH}/${pkg}/specs/${pkg}.spec:/opt/sandbox/${pkg}.spec \
           -v ${RPM_RESULT_DIR}:/opt/sandbox/RPMS \
           -u ${UID} \
           fuel/rpmbuild_env /bin/bash /opt/sandbox/build_rpm_in_docker.sh
done

# build deb packages
for pkg in ${BUILD_DEB_PACKAGES}; do
  docker run --rm -u ${UID} \
           -v ${SOURCE_PATH}/${pkg}:/opt/sandbox/SOURCES \
           -v ${DEB_RESULT_DIR}:/opt/sandbox/DEB \
           fuel/debbuild_env /bin/bash /opt/sandbox/build_deb_in_docker.sh
done

# preparing artifacts
find ${RPM_RESULT_DIR} -type f -name '*.rpm' -exec cp -v {} ${ARTS_DIR} \;
find ${DEB_RESULT_DIR} -type f -name '*.deb' -exec cp -v {} ${ARTS_DIR} \;
