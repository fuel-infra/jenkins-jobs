export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

export FEATURE_GROUPS=mirantis

PROD_VER=`grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2`
export ISO_NAME=fuel-$PROD_VER-$BUILD_NUMBER-$BUILD_ID
export UPGRADE_TARBALL_NAME=fuel-$PROD_VER-upgrade-$BUILD_NUMBER-$BUILD_ID
export ARTIFACT_NAME=fuel-$PROD_VER-artifacts-$BUILD_NUMBER-$BUILD_ID
export ARTIFACT_DIFF_NAME=fuel-$PROD_VER-diff-$BUILD_NUMBER-$BUILD_ID


# Available choices: msk srt usa hrk none
export USE_MIRROR=msk

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

echo "STEP 1. Get artifacts from ${BASE_VERSION}"
export DEPS_DATA_DIR="$DEPS_DIR/${BASE_VERSION}"
mkdir -p "${DEPS_DATA_DIR}"

DATA_URL="http://jenkins-product.srt.mirantis.net:8080/job/${BASE_VERSION}.all"
DATA_BUILD_NUMBER=`curl -s "${DATA_URL}/lastSuccessfulBuild/buildNumber"`
echo "$DATA_URL/$DATA_BUILD_NUMBER" > $WORKSPACE/data_build_url.txt
export DATA_MAGNET_LINK=`curl -s "${DATA_URL}/${DATA_BUILD_NUMBER}/artifact/artifacts_magnet_link.txt" | sed 's~.*MAGNET_LINK=~~'`

DATA_FILE=`seedclient-wrapper -dvm "${DATA_MAGNET_LINK}" --force-set-symlink -o "${DEPS_DATA_DIR}"`
tar xvf "${DATA_FILE}" -C "${DEPS_DATA_DIR}"

#########################################

echo "STEP 2. Make everything"
make UPGRADE_VERSIONS="${PROD_VER}:${BASE_VERSION}" BASE_VERSION=${BASE_VERSION} iso img upgrade-lrzip bootstrap docker centos-repo ubuntu-repo centos-diff-repo ubuntu-diff-repo version-yaml openstack-yaml

#########################################

echo "STEP 3. Pack artifacts"
cd ${ARTS_DIR}
tar cvf "${ARTIFACT_NAME}.tar" bootstrap.tar.gz centos-repo.tar ubuntu-repo.tar puppet.tgz openstack.yaml version.yaml fuel-images.tar.lrz

#########################################

echo "STEP 4. Pack diffs"
cd ${ARTS_DIR}
tar cvf "${ARTIFACT_DIFF_NAME}.tar" puppet.tgz version.yaml openstack.yaml diff*

#########################################

echo "STEP 5. Publish everything"

export LOCAL_STORAGE='/var/www/fuelweb-iso'
export HTTP_ROOT="http://`hostname -f`/fuelweb-iso"

cd ${ARTS_DIR}
for artifact in `ls fuel-*`
do
 ${WORKSPACE}/utils/jenkins/process_artifacts.sh $artifact
done

cd ${WORKSPACE}

cp $LOCAL_MIRROR/*changelog ${ARTS_DIR}/ || true
cp ${BUILD_DIR}/iso/isoroot/version.yaml ${WORKSPACE}/version.yaml.txt || true
(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${WORKSPACE}/listing.txt || true

grep MAGNET_LINK ${ARTS_DIR}/fuel-*.iso.data.txt > ${WORKSPACE}/magnet_link.txt
grep MAGNET_LINK ${ARTS_DIR}/fuel-*-diff-*.data.txt > ${WORKSPACE}/diff_magnet_link.txt
grep MAGNET_LINK ${ARTS_DIR}/fuel-*-artifacts-*.data.txt > ${WORKSPACE}/artifacts_magnet_link.txt
grep MAGNET_LINK ${ARTS_DIR}/fuel-*upgrade-*.data.txt > ${WORKSPACE}/upgrade_magnet_link.txt

#########################################

echo "STEP 6. Generate build description"

ISO_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"
