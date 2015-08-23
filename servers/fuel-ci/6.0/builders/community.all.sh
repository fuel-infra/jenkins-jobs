export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

export FEATURE_GROUPS=experimental

PROD_VER=`grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2`
export ISO_NAME=fuel-community-$PROD_VER-$BUILD_NUMBER-${BUILD_TIMESTAMP}
export UPGRADE_TARBALL_NAME=fuel-community-$PROD_VER-upgrade-$BUILD_NUMBER-${BUILD_TIMESTAMP}
export ARTIFACT_NAME=fuel-community-$PROD_VER-artifacts-$BUILD_NUMBER-${BUILD_TIMESTAMP}
export ARTIFACT_DIFF_NAME=fuel-community-$PROD_VER-diff-$BUILD_NUMBER-${BUILD_TIMESTAMP}

export USE_MIRROR=ext

export BUILD_DIR=${WORKSPACE}/../tmp/${JOB_NAME}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

export ARTS_DIR=${WORKSPACE}/artifacts
rm -rf ${ARTS_DIR}

export DEPS_DIR=${BUILD_DIR}/deps
rm -rf "${DEPS_DIR}"

#########################################

test "$deep_clean" = "true" && make deep_clean

echo "STEP 0. PROD_VER=${PROD_VER} BASE_VERSION=${BASE_VERSION} UPGRADE_VERSIONS=${PROD_VER}:${BASE_VERSION}"

#########################################

echo "Check version.yaml for Fuel commit ids (if present)"

if [ -n "${FUEL_COMMITS}" ] && [ -f "/home/jenkins/workspace/fuel_commits/${FUEL_COMMITS}" ]; then
  export FUEL_COMMITS=/home/jenkins/workspace/fuel_commits/${FUEL_COMMITS}
  export ASTUTE_COMMIT=$(fgrep astute_sha ${FUEL_COMMITS}|cut -d\" -f2)
  export FUELLIB_COMMIT=$(fgrep fuellib_sha ${FUEL_COMMITS}|cut -d\" -f2)
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

echo "STEP 1. Get artifacts from ${BASE_VERSION}"
export DEPS_DATA_DIR="$DEPS_DIR/${BASE_VERSION}"
mkdir -p "${DEPS_DATA_DIR}"

DATA_URL="${JENKINS_URL}job/${BASE_VERSION}-community.all"
DATA_BUILD_NUMBER=`curl -s "${DATA_URL}/lastSuccessfulBuild/buildNumber"`
echo "$DATA_URL/$DATA_BUILD_NUMBER" > $WORKSPACE/data_build_url.txt
if [ -z "${DATA_MAGNET_LINK}" ]; then
  export DATA_MAGNET_LINK=`curl -s "${DATA_URL}/${DATA_BUILD_NUMBER}/artifact/artifacts_torrent_link.txt" | sed 's~.*MAGNET_LINK=~~'`
fi
DATA_FILE=`seedclient-wrapper -dvm "${DATA_MAGNET_LINK}" --force-set-symlink -o "${DEPS_DATA_DIR}"`
tar xvf "${DATA_FILE}" -C "${DEPS_DATA_DIR}"

#########################################

echo "STEP 2. Make everything"
make UPGRADE_VERSIONS="${PROD_VER}:${BASE_VERSION}" BASE_VERSION=${BASE_VERSION} iso img upgrade-lrzip bootstrap docker centos-repo ubuntu-repo centos-diff-repo ubuntu-diff-repo version-yaml openstack-yaml

#########################################

echo "STEP 3. Pack artifacts"
cd ${ARTS_DIR}
tar cvf "${ARTIFACT_NAME}.tar" bootstrap.tar.gz centos-repo.tar ubuntu-repo.tar puppet.tgz openstack.yaml version.yaml fuel-images.tar.*

#########################################

echo "STEP 4. Pack diffs"
cd ${ARTS_DIR}
tar cvf "${ARTIFACT_DIFF_NAME}.tar" puppet.tgz version.yaml openstack.yaml diff*

#########################################

echo "STEP 5. Publish everything"

cd ${WORKSPACE}

cp $LOCAL_MIRROR/*changelog ${ARTS_DIR}/ || true
cp ${BUILD_DIR}/iso/isoroot/version.yaml ${WORKSPACE}/version.yaml.txt || true
(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${WORKSPACE}/listing.txt || true

##5.1) artifacts
seedclient.py -pvf "${ARTS_DIR}/${ARTIFACT_NAME}.tar" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

# Preparing description + torrent link for upstream jobs
echo http://seed.fuel-infra.org/fuelweb-iso/${ARTIFACT_NAME}.tar.torrent > ${WORKSPACE}/artifacts_torrent_link.txt
echo "<a href=http://seed.fuel-infra.org/fuelweb-iso/${ARTIFACT_NAME}.tar.torrent>${ARTIFACT_NAME}</a>"

##5.2) diff artifacts
seedclient.py -pvf "${ARTS_DIR}/${ARTIFACT_DIFF_NAME}.tar" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

# Preparing description + torrent link for upstream jobs
echo http://seed.fuel-infra.org/fuelweb-iso/${ARTIFACT_DIFF_NAME}.tar.torrent > ${WORKSPACE}/diff_torrent_link.txt
echo "<a href=http://seed.fuel-infra.org/fuelweb-iso/${ARTIFACT_DIFF_NAME}.tar.torrent>${ARTIFACT_DIFF_NAME}</a>"
