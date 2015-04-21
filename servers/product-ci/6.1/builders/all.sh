export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

echo STARTED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" > ci_status_params.txt

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

echo "STEP 0. PROD_VER=${PROD_VER} BASE_VERSION=${BASE_VERSION} UPGRADE_VERSIONS=${PROD_VER}:${BASE_VERSION} (`date -u`)"

#########################################

echo "STEP 1. Get artifacts from ${BASE_VERSION} (`date -u`)"
export DEPS_DATA_DIR="$DEPS_DIR/${BASE_VERSION}"
mkdir -p "${DEPS_DATA_DIR}"

DATA_URL="http://jenkins-product.srt.mirantis.net:8080/job/${BASE_VERSION}.all"
DATA_BUILD_NUMBER=`curl -s "${DATA_URL}/lastSuccessfulBuild/buildNumber"`
echo "$DATA_URL/$DATA_BUILD_NUMBER" > $WORKSPACE/data_build_url.txt
if [ -z "${DATA_MAGNET_LINK}" ]; then
  export DATA_MAGNET_LINK=`curl -s "${DATA_URL}/${DATA_BUILD_NUMBER}/artifact/artifacts_magnet_link.txt" | sed 's~.*MAGNET_LINK=~~'`
fi

echo "STEP 1.1. download and extract artifacts (`date -u`)"
DATA_FILE=`/usr/bin/time seedclient-wrapper -dvm "${DATA_MAGNET_LINK}" --force-set-symlink -o "${DEPS_DATA_DIR}"`
/usr/bin/time tar xvf "${DATA_FILE}" -C "${DEPS_DATA_DIR}"

#########################################

echo "STEP 2. Make everything (`date -u`)"
/usr/bin/time make ${make_args} UPGRADE_VERSIONS="${PROD_VER}:${BASE_VERSION}" BASE_VERSION=${BASE_VERSION} iso upgrade-lrzip bootstrap docker centos-repo ubuntu-repo centos-diff-repo ubuntu-diff-repo version-yaml openstack-yaml

#########################################

echo "STEP 3. Pack artifacts (`date -u`)"
cd ${ARTS_DIR}
/usr/bin/time tar cvf "${ARTIFACT_NAME}.tar" bootstrap.tar.gz centos-repo.tar ubuntu-repo.tar openstack.yaml version.yaml fuel-images.tar.*

#########################################

echo "STEP 4. Pack diffs (`date -u`)"
cd ${ARTS_DIR}
/usr/bin/time tar cvf "${ARTIFACT_DIFF_NAME}.tar" version.yaml openstack.yaml diff*

#########################################

echo "STEP 5. Publish everything (`date -u`)"

export LOCAL_STORAGE='/var/www/fuelweb-iso'
export HTTP_ROOT="http://`hostname -f`/fuelweb-iso"

cd ${ARTS_DIR}
for artifact in `ls fuel-*`
do
  /usr/bin/time ${WORKSPACE}/utils/jenkins/process_artifacts.sh $artifact
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

echo "STEP 6. Generate build description (`date -u`)"

ISO_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"

if [ "${trigger_community_build}" = "true" ]; then
  scp ${WORKSPACE}/version.yaml.txt build1.fuel-infra.org:/home/jenkins/workspace/fuel_commits/${PROD_VER}-${BUILD_NUMBER}.yaml
  curl -X POST https://fuel-jenkins.mirantis.com/job/${PROD_VER}-community.all/buildWithParameters\?FUEL_COMMITS\=${PROD_VER}-${BUILD_NUMBER}.yaml \
  --user product-ci:${AUTH_TOKEN}
fi

echo "BUILD FINISHED. (`date -u`)"

echo FINISHED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" >> ci_status_params.txt
