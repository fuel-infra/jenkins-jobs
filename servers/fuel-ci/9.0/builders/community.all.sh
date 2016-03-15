#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

PROD_VER=$(grep '^PRODUCT_VERSION' config.mk | cut -d= -f2)

export FEATURE_GROUPS="experimental"

export PRODUCT_VERSION="$PROD_VER"
export ISO_NAME="fuel-${ISO_ID}-${BUILD_NUMBER}-${BUILD_TIMESTAMP}"

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${WORKSPACE}/artifacts"
rm -rf "${ARTS_DIR}"
mkdir -p "${ARTS_DIR}"

############### Get MIRROR URLs ###############

# 1. Define closest mirror based on server location

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    srt)
        CLOSEST_MIRROR_URL="http://osci-mirror-srt.srt.mirantis.net"
        ;;
    msk)
        CLOSEST_MIRROR_URL="http://osci-mirror-msk.msk.mirantis.net"
        ;;
    hrk)
        CLOSEST_MIRROR_URL="http://osci-mirror-kha.kha.mirantis.net"
        ;;
    poz|bud|budext|cz)
        CLOSEST_MIRROR_URL="http://mirror.seed-cz1.fuel-infra.org"
        ;;
    scc)
        CLOSEST_MIRROR_URL="http://mirror.seed-us1.fuel-infra.org"
        ;;
    *)
        CLOSEST_MIRROR_URL="http://mirror.fuel-infra.org"
esac

# 2. Get Upstream Ubuntu mirror snapshot

if [ "${UBUNTU_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror and set the mirror id
    UBUNTU_MIRROR_URL=$(curl "${CLOSEST_MIRROR_URL}/pkgs/ubuntu-latest.htm")
    UBUNTU_MIRROR_ID=$(expr "${UBUNTU_MIRROR_URL}" : '.*/\(ubuntu-.*\)')
fi

# make system uses both MIRROR_UBUNTU and MIRROR_UBUNTU_ROOT
# parameters and concatenates them

export MIRROR_UBUNTU="${CLOSEST_MIRROR_URL#http://}"
export MIRROR_UBUNTU_ROOT="/pkgs/${UBUNTU_MIRROR_ID}"

echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > "${ARTS_DIR}/ubuntu_mirror_id.txt"

# 3. Get MOS Ubuntu mirror snapshot

export MIRROR_MOS_UBUNTU="${CLOSEST_MIRROR_URL#http://}"
LATEST_TARGET_MOS_UBUNTU=$(curl -sSf "http://${MIRROR_MOS_UBUNTU}/${MOS_UBUNTU_ROOT}/${MOS_UBUNTU_TARGET}" | head -1)
export MIRROR_MOS_UBUNTU_ROOT="${MOS_UBUNTU_ROOT}/${LATEST_TARGET_MOS_UBUNTU}"

echo "MOS_UBUNTU_MIRROR_ID=${LATEST_TARGET_MOS_UBUNTU}" > "${ARTS_DIR}/mos_ubuntu_mirror_id.txt"

# 4. Get Upstream CentOS mirror snapshot

if [ "${CENTOS_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror and set the mirror id
    CENTOS_MIRROR_URL=$(curl "${CLOSEST_MIRROR_URL}/pkgs/centos-latest.htm")
    CENTOS_MIRROR_ID=$(expr "${CENTOS_MIRROR_URL}" : '.*/\(centos-.*\)')
fi

MIRROR_CENTOS_ROOT="pkgs/${CENTOS_MIRROR_ID}"

# make system uses MIRROR_CENTOS parameter directly

export MIRROR_CENTOS="${CLOSEST_MIRROR_URL}/${MIRROR_CENTOS_ROOT}"

echo "CENTOS_MIRROR_ID=${CENTOS_MIRROR_ID}" > "${ARTS_DIR}/centos_mirror_id.txt"

# 5. Get MOS CentOS mirror (Fuel) snapshot

LATEST_TARGET_MOS_CENTOS=$(curl -sSf "${CLOSEST_MIRROR_URL}/${MOS_CENTOS_ROOT}/os.target.txt" | head -1)
export MIRROR_FUEL="${CLOSEST_MIRROR_URL}/${MOS_CENTOS_ROOT}/${LATEST_TARGET_MOS_CENTOS}/x86_64"

echo "MOS_CENTOS_MIRROR_ID=${LATEST_TARGET_MOS_CENTOS}" > "${ARTS_DIR}/mos_centos_mirror_id.txt"

############### Done defining mirrors ###############

export FEATURE_GROUPS="experimental"

make deep_clean
rm -rf /var/tmp/yum-"${USER}"-*

#########################################

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU}${MIRROR_MOS_UBUNTU_ROOT} and ${MIRROR_FUEL}"

#########################################

echo "STEP 0. Clean before start"
make deep_clean

rm -rf /var/tmp/yum-${USER}-*

#########################################

echo "STEP 1. Make everything"

make $make_args iso listing

#########################################

echo "STEP 2. Publish everything"

cd "${WORKSPACE}"

cp "${LOCAL_MIRROR}"/*changelog "${ARTS_DIR}/" || true
cp "${BUILD_DIR}/listing-package-changelog.txt" "${ARTS_DIR}/listing-package-changelog.txt" || true
(cd "${BUILD_DIR}/iso/isoroot" && find . | sed -s 's/\.\///') > "${ARTS_DIR}/listing.txt" || true

#########################################

echo "STEP 3. Clean after build"

cd ${WORKSPACE}

make deep_clean

#########################################
