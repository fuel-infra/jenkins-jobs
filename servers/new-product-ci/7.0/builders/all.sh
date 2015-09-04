#!/bin/bash

set -ex

echo STARTED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" > ci_status_params.txt

export FEATURE_GROUPS="mirantis"

PROD_VER=$(grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2)
export ISO_NAME=fuel-$PROD_VER-$BUILD_NUMBER-${BUILD_TIMESTAMP}
export UPGRADE_TARBALL_NAME=fuel-$PROD_VER-upgrade-$BUILD_NUMBER-${BUILD_TIMESTAMP}

# Available choices: msk srt usa hrk none
export USE_MIRROR=msk

export BUILD_DIR=${WORKSPACE}/../tmp/${JOB_NAME}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

export ARTS_DIR=${WORKSPACE}/artifacts
rm -rf ${ARTS_DIR}

######## Get node location to choose closer mirror ###############
# try to use facter and fall-back to bud location

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    srt)
        USE_MIRROR=srt
        LATEST_MIRROR_ID_URL=http://osci-mirror-srt.srt.mirantis.net
        ;;
    msk)
        USE_MIRROR=msk
        LATEST_MIRROR_ID_URL=http://osci-mirror-msk.msk.mirantis.net
        ;;
    hrk)
        USE_MIRROR=hrk
        LATEST_MIRROR_ID_URL=http://osci-mirror-kha.kha.mirantis.net
        ;;
    poz|bud|bud-ext|cz)
        USE_MIRROR=cz
        LATEST_MIRROR_ID_URL=http://mirror.seed-cz1.fuel-infra.org
        ;;
    mnv)
        USE_MIRROR=usa
        LATEST_MIRROR_ID_URL=http://mirror.seed-us1.fuel-infra.org
        ;;
    *)
        USE_MIRROR=msk
        LATEST_MIRROR_ID_URL=http://osci-mirror-msk.msk.mirantis.net
esac

LATEST_TARGET=$(curl -sSf "${LATEST_MIRROR_ID_URL}/mos-repos/ubuntu/7.0.target.txt" | head -1)
export MIRROR_MOS_UBUNTU_ROOT="/mos-repos/ubuntu/${LATEST_TARGET}"

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU_ROOT}"

#########################################

test "$deep_clean" = "true" && make deep_clean

#########################################

echo "STEP 1. Make everything"
make ${make_args} iso upgrade-lrzip version-yaml openstack-yaml

#########################################

echo "STEP 2. Publish everything"

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
grep MAGNET_LINK ${ARTS_DIR}/fuel-*upgrade-*.data.txt > ${WORKSPACE}/upgrade_magnet_link.txt

#########################################

echo "STEP 3. Generate build description"

ISO_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"

if [ "${trigger_community_build}" = "true" ]; then
  scp ${WORKSPACE}/version.yaml.txt build1.fuel-infra.org:/home/jenkins/workspace/fuel_commits/${PROD_VER}-${BUILD_NUMBER}.yaml
  curl -X POST https://ci.fuel-infra.org/job/${PROD_VER}-community.all/buildWithParameters\?FUEL_COMMITS\=${PROD_VER}-${BUILD_NUMBER}.yaml \
  --user product-ci:${FUEL_CI_API_TOKEN}
fi

echo "BUILD FINISHED."

echo FINISHED_TIME="`date -u +'%Y-%m-%dT%H:%M:%S'`" >> ci_status_params.txt
