#!/bin/bash

set -ex

if [ ! -z "${CUSTOM_PROJECT_PACKAGE}" ]; then
  PROJECT_PACKAGE="${CUSTOM_PROJECT_PACKAGE}"
fi

## we MUST use external DNS
echo "DNSPARAM=\"--dns 8.8.8.8\"" > "${WORKSPACE}"/fuel-mirror/perestroika/docker-builder/config

# where we store sources, this dir will be mounted to docker env
SOURCE_PATH="${WORKSPACE}/sources/"
# where we store packages, that should be uploaded by test
PACKAGES_DIR="${UPDATE_FUEL_PATH}"
# where we checkout fuel-library code
PROJECT_ROOT="${WORKSPACE}/${PROJECT}"

rm -rf "${SOURCE_PATH}" "${PACKAGES_DIR}"
mkdir -p "${SOURCE_PATH}" "${PACKAGES_DIR}"

# where docker will store results (builded packages)
RPM_RESULT_DIR="${WORKSPACE}/packages_rpm"
DEB_RESULT_DIR="${WORKSPACE}/packages_deb"
rm -rf "${RPM_RESULT_DIR}" "${DEB_RESULT_DIR}"
mkdir -p "${RPM_RESULT_DIR}" "${DEB_RESULT_DIR}"

# prepare fuel-library sources
pushd "${PROJECT_ROOT}" &>/dev/null

# taking version of package
RPM_PACKAGE_VERSION=$(rpm -q \
  --specfile "${PROJECT_ROOT}"/specs/"${PROJECT_PACKAGE}".spec \
  --queryformat %{VERSION}"\n" | head -1 )

if [ -z "${GERRIT_BRANCH}" ] || [ "${GERRIT_BRANCH}" == 'master' ]; then
# we start job from master branch
  NUMBER_OF_COMMITS=$(git -C "${PROJECT_ROOT}" rev-list --no-merges HEAD --count)
  LAST_COMMIT_SHORT_HASH=$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD)
  IDENTIFIER="1.git"
else
# this is patchset
  NUMBER_OF_COMMITS=$(git -C "${PROJECT_ROOT}" rev-list --no-merges "gerrit/${GERRIT_BRANCH}" --count)
  LAST_COMMIT_SHORT_HASH=$(git -C "${PROJECT_ROOT}" rev-parse --short "gerrit/${GERRIT_BRANCH}")
  IDENTIFIER="2.gerrit${GERRIT_CHANGE_NUMBER}.${GERRIT_PATCHSET_NUMBER}.git"
fi

RELEASE="${NUMBER_OF_COMMITS}.${IDENTIFIER}${LAST_COMMIT_SHORT_HASH}"

export DEBFULLNAME=$(git -C "${PROJECT_ROOT}" log -1 --pretty=format:%an)
export DEBEMAIL=$(git -C "${PROJECT_ROOT}" log -1 --pretty=format:%ae)
DEBMSG=$(git -C "${PROJECT_ROOT}" log -1 --pretty=%s)

# for rpm
git archive --format=tar.gz --worktree-attributes HEAD \
  --output="${SOURCE_PATH}/${PROJECT_PACKAGE}-${RPM_PACKAGE_VERSION}.tar.gz"

cp -v "${PROJECT_ROOT}/specs/${PROJECT_PACKAGE}.spec" "${SOURCE_PATH}"

# update spec with proper version
sed -i "s|Release:.*$|Release: ${RELEASE}|" "${SOURCE_PATH}/${PROJECT_PACKAGE}.spec"

# select correct repository suffix for new MOS versions
if [[ "${MOS}" =~ ^[4-8].* ]]; then
  REPO_SUFFIX='-fuel'
else
  REPO_SUFFIX=''
fi

## build rpm
"${WORKSPACE}"/fuel-mirror/perestroika/build-package.sh \
  --build-target centos7 \
  --ext-repos "mos,http://mirror.seed-cz1.fuel-infra.org/mos-repos/centos/mos${MOS}-centos7${REPO_SUFFIX}/os/x86_64/" \
  --source "${SOURCE_PATH}" \
  --output-dir "${RPM_RESULT_DIR}"

# for deb
if [ -d "${PROJECT_ROOT}/debian" ]; then
  DEB_PACKAGE_VERSION=$(dpkg-parsechangelog --show-field Version | cut -d '-' -f1)
  cp -v "${SOURCE_PATH}/${PROJECT_PACKAGE}-${RPM_PACKAGE_VERSION}.tar.gz" "${SOURCE_PATH}/${PROJECT_PACKAGE}_${DEB_PACKAGE_VERSION}.orig.tar.gz"
  mkdir -p "${SOURCE_PATH}/${PROJECT_PACKAGE}"
  cp -rv "${PROJECT_ROOT}/debian" "${SOURCE_PATH}/${PROJECT_PACKAGE}"

  dch -c "${SOURCE_PATH}/${PROJECT_PACKAGE}/debian/changelog" \
    -D trusty \
    -b --force-distribution \
    -v "${DEB_PACKAGE_VERSION}-${RELEASE}" "${DEBMSG}"
  ## build deb
  "${WORKSPACE}"/fuel-mirror/perestroika/build-package.sh \
    --build-target trusty \
    --ext-repos "http://mirror.seed-cz1.fuel-infra.org/mos-repos/ubuntu/${MOS} mos${MOS} main restricted" \
    --source "${SOURCE_PATH}" \
    --output-dir "${DEB_RESULT_DIR}"
fi

popd &>/dev/null

# preparing artifacts
echo "Copy packages to artifacts dir"
find "${RPM_RESULT_DIR}" -type f -name '*.rpm' -exec cp -r {} "${PACKAGES_DIR}" \;
find "${DEB_RESULT_DIR}" -type f -name '*.deb' -exec cp -r {} "${PACKAGES_DIR}" \;
