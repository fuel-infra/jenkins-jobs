#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

PROD_VER=$(grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2)
export ISO_NAME="fuel-gerrit-${PROD_VER}-${BUILD_NUMBER}-${BUILD_ID}"
export UPGRADE_TARBALL_NAME="fuel-gerrit-${PROD_VER}-upgrade-${BUILD_NUMBER}-${BUILD_ID}"

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${WORKSPACE}/artifacts"
rm -rf "${ARTS_DIR}"

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

#########################################

echo "STEP 1. Make everything (`date -u`)"
make ${make_args} iso upgrade-lrzip version-yaml openstack-yaml

#########################################

echo "STEP 2. Publish everything (`date -u`)"

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
grep MAGNET_LINK ${ARTS_DIR}/fuel-*upgrade-*.data.txt > ${WORKSPACE}/upgrade_magnet_link.txt

#########################################

echo "STEP 3. Generate build description (`date -u`)"

UPGRADE_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*upgrade-*.data.txt | sed 's/MAGNET_LINK=//'`
UPGRADE_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*upgrade-*.data.txt | sed 's/HTTP_LINK=//'`
UPGRADE_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*upgrade-*.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$UPGRADE_HTTP_LINK">UPGD download link</a> <a href="$UPGRADE_HTTP_TORRENT">UPGD torrent link</a><br>${UPGRADE_MAGNET_LINK}<br>"

echo "BUILD FINISHED. (`date -u`)"
