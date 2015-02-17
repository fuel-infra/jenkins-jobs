#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

PROD_VER=$(grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2)
export ISO_NAME="fuel-${PROD_VER}-${BUILD_NUMBER}-${BUILD_ID}"
export UPGRADE_TARBALL_NAME="fuel-${PROD_VER}-upgrade-${BUILD_NUMBER}-${BUILD_ID}"
export ARTIFACT_NAME="fuel-${PROD_VER}-artifacts-${BUILD_NUMBER}-${BUILD_ID}"
export ARTIFACT_DIFF_NAME="fuel-${PROD_VER}-diff-${BUILD_NUMBER}-${BUILD_ID}"


export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${WORKSPACE}/artifacts"
rm -rf "${ARTS_DIR}"

export DEPS_DIR="${BUILD_DIR}/deps"
rm -rf "${DEPS_DIR}"

# Checking gerrit commits for fuel-main
if [ "${FUELMAIN_COMMIT}" != "master" ] ; then
    git checkout ${FUELMAIN_COMMIT}
fi

# Checking gerrit commits for fuel-main
if [ "${fuelmain_gerrit_commit}" != "none" ] ; then
  for commit in ${fuelmain_gerrit_commit} ; do
    git fetch https://review.openstack.org/stackforge/fuel-main "${commit}" && git cherry-pick FETCH_HEAD || false
  done
fi

export NAILGUN_GERRIT_COMMIT="${nailgun_gerrit_commit}"
export ASTUTE_GERRIT_COMMIT="${astute_gerrit_commit}"
export OSTF_GERRIT_COMMIT="${ostf_gerrit_commit}"
export FUELLIB_GERRIT_COMMIT="${fuellib_gerrit_commit}"
export PYTHON_FUELCLIENT_GERRIT_COMMIT="${python_fuelclient_gerrit_commit}"

#########################################

make deep_clean

echo "STEP 0. PROD_VER=${PROD_VER} BASE_VERSION=${BASE_VERSION} UPGRADE_VERSIONS=${PROD_VER}:${BASE_VERSION} (`date -u`)"

#########################################

echo "STEP 1. Get artifacts from ${BASE_VERSION} (`date -u`)"
export DEPS_DATA_DIR="${DEPS_DIR}/${BASE_VERSION}"
mkdir -p "${DEPS_DATA_DIR}"

DATA_URL="http://jenkins-product.srt.mirantis.net:8080/job/${BASE_VERSION}.all"
DATA_BUILD_NUMBER=$(curl -s "${DATA_URL}/lastSuccessfulBuild/buildNumber")
echo "${DATA_URL}/${DATA_BUILD_NUMBER}" > "${WORKSPACE}/data_build_url.txt"
if [ -z "${DATA_MAGNET_LINK}" ]; then
  export DATA_MAGNET_LINK=$(curl -s "${DATA_URL}/${DATA_BUILD_NUMBER}/artifact/artifacts_magnet_link.txt" | sed 's~.*MAGNET_LINK=~~')
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
for artifact in $(ls fuel-*)
do
  /usr/bin/time ${WORKSPACE}/utils/jenkins/process_artifacts.sh ${artifact}
done

cd ${WORKSPACE}

echo FUELMAIN_GERRIT_COMMIT="${fuelmain_gerrit_commit}" > ${ARTS_DIR}/gerrit_commits.txt
echo NAILGUN_GERRIT_COMMIT="${nailgun_gerrit_commit}" >> ${ARTS_DIR}/gerrit_commits.txt
echo ASTUTE_GERRIT_COMMIT="${astute_gerrit_commit}" >> ${ARTS_DIR}/gerrit_commits.txt
echo OSTF_GERRIT_COMMIT="${ostf_gerrit_commit}" >> ${ARTS_DIR}/gerrit_commits.txt
echo FUELLIB_GERRIT_COMMIT="${fuellib_gerrit_commit}" >> ${ARTS_DIR}/gerrit_commits.txt
echo PYTHON_FUELCLIENT_GERRIT_COMMIT="${python_fuelclient_gerrit_commit}" >> ${ARTS_DIR}/gerrit_commits.txt

cp $LOCAL_MIRROR/*changelog ${ARTS_DIR}/ || true
cp ${BUILD_DIR}/iso/isoroot/version.yaml ${WORKSPACE}/version.yaml.txt || true
(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${WORKSPACE}/listing.txt || true

grep MAGNET_LINK ${ARTS_DIR}/fuel-*.iso.data.txt > ${WORKSPACE}/magnet_link.txt
grep MAGNET_LINK ${ARTS_DIR}/fuel-*-diff-*.data.txt > ${WORKSPACE}/diff_magnet_link.txt
grep MAGNET_LINK ${ARTS_DIR}/fuel-*-artifacts-*.data.txt > ${WORKSPACE}/artifacts_magnet_link.txt
grep MAGNET_LINK ${ARTS_DIR}/fuel-*upgrade-*.data.txt > ${WORKSPACE}/upgrade_magnet_link.txt

#########################################

echo "STEP 6. Generate build description (`date -u`)"

UPGRADE_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*upgrade-*.data.txt | sed 's/MAGNET_LINK=//'`
UPGRADE_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*upgrade-*.data.txt | sed 's/HTTP_LINK=//'`
UPGRADE_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*upgrade-*.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$UPGRADE_HTTP_LINK">UPGD download link</a> <a href="$UPGRADE_HTTP_TORRENT">UPGD torrent link</a><br>${UPGRADE_MAGNET_LINK}<br>"

echo "BUILD FINISHED. (`date -u`)"
