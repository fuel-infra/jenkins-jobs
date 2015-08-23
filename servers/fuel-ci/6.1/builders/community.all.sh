#!/bin/bash

set -ex

export FEATURE_GROUPS="experimental"

PROD_VER=$(grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2)
export ISO_NAME="fuel-community-${PROD_VER}-${BUILD_NUMBER}-${BUILD_TIMESTAMP}"
export UPGRADE_TARBALL_NAME="fuel-community-${PROD_VER}-upgrade-${BUILD_NUMBER}-${BUILD_TIMESTAMP}"

export USE_MIRROR=ext

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR=${WORKSPACE}/artifacts
rm -rf ${ARTS_DIR}

#########################################

test "$deep_clean" = "true" && make deep_clean

#########################################

echo "Check version.yaml for Fuel commit ids (if present)"

if [ -n "${FUEL_COMMITS}" ] && [ -f "/home/jenkins/workspace/fuel_commits/${FUEL_COMMITS}" ]; then
  export FUEL_COMMITS=/home/jenkins/workspace/fuel_commits/${FUEL_COMMITS}
  export ASTUTE_COMMIT=$(fgrep astute_sha ${FUEL_COMMITS}|cut -d\" -f2)
  export FUELLIB_COMMIT=$(fgrep fuel-library_sha ${FUEL_COMMITS}|cut -d\" -f2)
  export FUELMAIN_COMMIT=$(fgrep fuelmain_sha ${FUEL_COMMITS}|cut -d\" -f2)
  export NAILGUN_COMMIT=$(fgrep nailgun_sha ${FUEL_COMMITS}|cut -d\" -f2)
  export OSTF_COMMIT=$(fgrep ostf_sha ${FUEL_COMMITS}|cut -d\" -f2)
  export PYTHON_FUELCLIENT_COMMIT=$(fgrep python-fuelclient_sha ${FUEL_COMMITS}|cut -d\" -f2)
fi

echo "Checkout fuel-main"

if [ -n "${FUELMAIN_COMMIT}" ] ; then
    git checkout ${FUELMAIN_COMMIT}
fi

#########################################

echo "STEP 1. Make everything"

make ${make_args} iso upgrade-lrzip version-yaml openstack-yaml

echo "STEP 2. Publish everything"

cd ${WORKSPACE}

cp $LOCAL_MIRROR/*changelog ${ARTS_DIR}/ || true
cp ${BUILD_DIR}/iso/isoroot/version.yaml ${WORKSPACE}/version.yaml.txt || true
(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${WORKSPACE}/listing.txt || true

echo "BUILD FINISHED."
