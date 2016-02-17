#!/bin/bash

set -ex

export FEATURE_GROUPS="experimental"

PROD_VER=$(grep '^PRODUCT_VERSION' config.mk | cut -d= -f2)
export ISO_NAME="fuel-community-${PROD_VER}-${BUILD_NUMBER}-${BUILD_TIMESTAMP}"

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${WORKSPACE}/artifacts"
rm -rf "${ARTS_DIR}"

#########################################

test "$deep_clean" = "true" && make deep_clean
rm -rf /var/tmp/yum-"${USER}"-*

#########################################


######## Get stable ubuntu mirror from snapshot ###############
# Since we are building community.iso in EU dc let' hardcode this
LATEST_MIRROR_ID_URL=http://mirror.seed-cz1.fuel-infra.org
LATEST_TARGET=$(curl -sSf "${LATEST_MIRROR_ID_URL}/mos-repos/ubuntu/master.target.txt" | head -1)

export MIRROR_MOS_UBUNTU_ROOT="/mos-repos/ubuntu/${LATEST_TARGET}"

export MIRROR_MOS_UBUNTU_SUITE=mos-master

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU_ROOT}"

echo "Checkout fuel-main"

if [ -n "${FUELMAIN_COMMIT}" ] ; then
    git checkout "${FUELMAIN_COMMIT}"
fi

#########################################
echo "STEP 0. Export Workarounds"
export MIRROR_FUEL=http://mirror.seed-cz1.fuel-infra.org/mos-repos/centos/mos9.0-centos7-fuel/os/x86_64/
export MIRROR_MOS_UBUNTU=mirror.seed-cz1.fuel-infra.org
export MIRROR_UBUNTU=mirror.seed-cz1.fuel-infra.org
export USE_MIRROR=ext

echo "STEP 1. Make everything"

make iso listing

echo "STEP 2. Publish everything"

cd "${WORKSPACE}"

cp "${LOCAL_MIRROR}/*changelog ${ARTS_DIR}/" || true
(cd "${BUILD_DIR}/iso/isoroot" && find . | sed -s 's/\.\///') > "${WORKSPACE}/listing.txt" || true
cp ${BUILD_DIR}/listing-build.txt ${WORKSPACE}/listing-build.txt || true
cp ${BUILD_DIR}/listing-local-mirror.txt ${WORKSPACE}/listing-local-mirror.txt || true
cp ${BUILD_DIR}/listing-package-changelog.txt ${WORKSPACE}/listing-package-changelog.txt || true


echo "BUILD FINISHED."

# cleanup after the job
# we can cleanup freely since make deep_clean doesn't wipe out ARTS_DIR
cd "${WORKSPACE}"
make deep_clean
