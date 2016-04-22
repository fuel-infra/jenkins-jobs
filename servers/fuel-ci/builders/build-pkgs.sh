#!/bin/bash

set -ex

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/"
        ;;
    poz|bud|bud-ext|budext|undef)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/"
        ;;
    mnv|scc|sccext)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/"
esac


## we MUST use external DNS
echo "DNSPARAM=\"--dns 8.8.8.8\"" > "${WORKSPACE}"/fuel-mirror/perestroika/docker-builder/config

# where we store sources, this dir will be mounted to docker env
SOURCE_PATH="${WORKSPACE}/sources/"
# where we store packages, that should be uploaded by test
PACKAGES_DIR="${WORKSPACE}/packages"
# where we checkout fuel-library code
PROJECT_ROOT="${WORKSPACE}/${PROJECT}"
# where docker will store results (builded packages)
RPM_RESULT_DIR="${WORKSPACE}/packages_rpm"
DEB_RESULT_DIR="${WORKSPACE}/packages_deb"

# clean previous artifacts
rm -rf "${SOURCE_PATH}" "${PACKAGES_DIR}"
rm -rf "${RPM_RESULT_DIR}" "${DEB_RESULT_DIR}"

# exit on disabled Fuel CI check
if echo "${GERRIT_CHANGE_COMMIT_MESSAGE}" | grep -q -iE "Fuel-CI:\s+disable"; then
  echo "Fuel CI check disabled"
  exit -1
fi

# recreate folders
mkdir -p "${SOURCE_PATH}" "${PACKAGES_DIR}"
mkdir -p "${RPM_RESULT_DIR}" "${DEB_RESULT_DIR}"

# prepare fuel-library sources
pushd "${PROJECT_ROOT}" &>/dev/null

# taking version of package

RPM_PACKAGE_VERSION=$(rpm -q --specfile "${PROJECT_ROOT}"/specs/"${PROJECT_PACKAGE}".spec --queryformat %{VERSION}"\n" | head -1 )

if [[ -z "${GERRIT_BRANCH}" || "${GERRIT_PROJECT}" == openstack/puppet* ]]; then
# we start job from master branch (by timer)
  RELEASE="$(git -C "${PROJECT_ROOT}" rev-list --no-merges HEAD --count).1.git$(git -C "${PROJECT_ROOT}" rev-parse --short HEAD)"
else
# this is patchset
  RELEASE="$(git -C "${PROJECT_ROOT}" rev-list --no-merges "gerrit/${GERRIT_BRANCH}" --count).2.gerrit${GERRIT_CHANGE_NUMBER}.${GERRIT_PATCHSET_NUMBER}.git$(git -C "${PROJECT_ROOT}" rev-parse --short "gerrit/${GERRIT_BRANCH}")"
fi
export DEBFULLNAME=$(git -C "${PROJECT_ROOT}" log -1 --pretty=format:%an)
export DEBEMAIL=$(git -C "${PROJECT_ROOT}" log -1 --pretty=format:%ae)
DEBMSG=$(git -C "${PROJECT_ROOT}" log -1 --pretty=%s)

# for rpm
# add local modifications (e.g. prepared upstream puppet modules) to source archive
git add -A
uploadStash=$(git stash create)
git archive --format=tar.gz --worktree-attributes ${uploadStash:-HEAD} --output="${SOURCE_PATH}/${PROJECT_PACKAGE}-${RPM_PACKAGE_VERSION}.tar.gz"
cp -v "${PROJECT_ROOT}/specs/${PROJECT_PACKAGE}.spec" "${SOURCE_PATH}"
# update spec with proper version
sed -i "s|Release:.*$|Release: ${RELEASE}|" "${SOURCE_PATH}/${PROJECT_PACKAGE}.spec"
## build rpm
"${WORKSPACE}"/fuel-mirror/perestroika/build-package.sh \
  --build-target centos7 \
  --ext-repos "mos,${MIRROR_HOST}mos-repos/centos/${RPM_MIRROR_BASE_NAME}/os/x86_64/" \
  --source "${SOURCE_PATH}" \
  --output-dir "${RPM_RESULT_DIR}"

# for deb
if [ -d "${PROJECT_ROOT}/debian" ]; then
  DEB_PACKAGE_VERSION=$(dpkg-parsechangelog --show-field Version | cut -d '-' -f1)
  cp -v "${SOURCE_PATH}/${PROJECT_PACKAGE}-${RPM_PACKAGE_VERSION}.tar.gz" "${SOURCE_PATH}/${PROJECT_PACKAGE}_${DEB_PACKAGE_VERSION}.orig.tar.gz"
  mkdir -p "${SOURCE_PATH}/${PROJECT_PACKAGE}"
  cp -rv "${PROJECT_ROOT}/debian" "${SOURCE_PATH}/${PROJECT_PACKAGE}"
  dch -c "${SOURCE_PATH}/${PROJECT_PACKAGE}/debian/changelog" -D trusty -b --force-distribution -v "${DEB_PACKAGE_VERSION}-${RELEASE}" "${DEBMSG}"
  ## build deb
  "${WORKSPACE}"/fuel-mirror/perestroika/build-package.sh \
    --upstream-repo "${MIRROR_HOST}pkgs/ubuntu/" \
    --build-target trusty \
    --ext-repos "${MIRROR_HOST}mos-repos/ubuntu/${DEB_MIRROR_BASE_NAME} main restricted" \
    --source "${SOURCE_PATH}" \
    --output-dir "${DEB_RESULT_DIR}"
fi

popd &>/dev/null

# preparing artifacts
echo "Copy packages to artifacts dir"
find "${RPM_RESULT_DIR}" -type f -name '*.rpm' -exec cp -r {} "${PACKAGES_DIR}" \;
find "${DEB_RESULT_DIR}" -type f -name '*.deb' -exec cp -r {} "${PACKAGES_DIR}" \;
