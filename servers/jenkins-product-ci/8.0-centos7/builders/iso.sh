#!/bin/bash

set -ex

echo STARTED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" > ci_status_params.txt

export FEATURE_GROUPS="mirantis"

PROD_VER=$(grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2)
export CENTOS_MAJOR=7
export CENTOS_MINOR=0
# export MIRROR_FUEL=http://perestroika-repo-tst.infra.mirantis.net/mos-repos/centos/mos8.0-centos7-fuel/os/x86_64
export MIRROR_FUEL=http://perestroika-repo-tst.infra.mirantis.net/mos-repos/centos/mos-master-centos7/os/x86_64

export ISO_NAME=fuel-centos7-$PROD_VER-$BUILD_NUMBER-${BUILD_TIMESTAMP}

export BUILD_DIR=${WORKSPACE}/../tmp/${JOB_NAME}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

export ARTS_DIR=${WORKSPACE}/artifacts
rm -rf ${ARTS_DIR}

# Checking gerrit commits for fuel-main
if [ "${fuelmain_gerrit_commit}" != "none" ] ; then
  for commit in ${fuelmain_gerrit_commit} ; do
    git fetch https://review.openstack.org/stackforge/fuel-main "${commit}" && git cherry-pick FETCH_HEAD || false
  done
fi

# No staging in 8.0
export USE_MIRROR=none

# Fix snapshot of a mirror which has been copied from 7.0 repositories

TARGET="snapshots/8.0-2015-09-02-000000"
export MIRROR_MOS_UBUNTU_ROOT="/mos-repos/ubuntu/${TARGET}"

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU_ROOT}"

#########################################

test "$deep_clean" = "true" && make deep_clean

#########################################
echo "Using mirrors"
make ${make_args} show-yum-repos-centos

make clean

echo "STEP 1. Make iso"
make ${make_args} iso

#########################################

echo "STEP 2. Publish iso"

export LOCAL_STORAGE='/var/www/fuelweb-iso'
export HTTP_ROOT="http://`hostname -f`/fuelweb-iso"

cd ${ARTS_DIR}
for artifact in `ls fuel-*`
do
  /usr/bin/time ${WORKSPACE}/utils/jenkins/process_artifacts.sh $artifact
done

cd ${WORKSPACE}

(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${WORKSPACE}/listing.txt || true

grep MAGNET_LINK ${ARTS_DIR}/fuel-*.iso.data.txt > ${WORKSPACE}/magnet_link.txt

#########################################

echo "STEP 3. Generate build description"

ISO_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"

echo "BUILD FINISHED."

echo FINISHED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" >> ci_status_params.txt
