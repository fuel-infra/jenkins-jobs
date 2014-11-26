# sample script to check that brackets aren't escaped
# when using the include-raw application yaml tag
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

export FEATURE_GROUPS=mirantis

PROD_VER=`grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2`
export ISO_NAME=fuel-$PROD_VER-$BUILD_NUMBER-$BUILD_ID
export UPGRADE_TARBALL_NAME=fuel-$PROD_VER-upgrade-$BUILD_NUMBER-$BUILD_ID
export ARTIFACT_NAME=fuel-$PROD_VER-artifacts-$BUILD_NUMBER-$BUILD_ID
export ARTIFACT_DIFF_NAME=fuel-$PROD_VER-diff-$BUILD_NUMBER-$BUILD_ID

# Available choices: msk srt usa hrk none
export USE_MIRROR=msk

export BUILD_DIR=$\{WORKSPACE\}/../tmp/$\{JOB_NAME\}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

export ARTS_DIR=${WORKSPACE}/artifacts
export DEPS_DIR=${BUILD_DIR}/deps

# PRODUCT_VERSION=6.0 BASE_VERSION=5.1.1 UPGRADE_VERSIONS=${PRODUCT_VERSION}:${BASE_VERSION}"
export BASE_VERSION=5.1.1


###1) make deep_clean
test "$deep_clean" = "true" && make deep_clean
# we need to clean arts_dir, if it's outside build_dir
rm -rf ${ARTS_DIR}


####2) build iso img and artifacts for the next jobs
make iso img bootstrap docker puppet centos-repo ubuntu-repo version-yaml openstack-yaml


####2.1) prepare artifacts for publishing
cd ${ARTS_DIR}
tar cvf "${ARTIFACT_NAME}.tar" bootstrap.tar.gz centos-repo.tar ubuntu-repo.tar puppet.tgz openstack.yaml version.yaml fuel-images.tar.lrz


####3) generating diff repo artifacts
# remove old artifacts, if any exists
rm -rf "${DEPS_DIR}"

## all arts from 5.1.1, because we need them for diff mirror too
export DEPS_DATA_DIR="$DEPS_DIR/5.1.1"
mkdir -p "${DEPS_DATA_DIR}"

export DATA_MAGNET_LINK=`curl -s 'http://jenkins-product.srt.mirantis.net:8080/job/5.1.1.all/lastSuccessfulBuild/artifact/artifacts_magnet_link.txt' | sed 's~.*MAGNET_LINK=~~'`

DATA_FILE=`seedclient-wrapper -dvm "${DATA_MAGNET_LINK}" --force-set-symlink -o "${DEPS_DATA_DIR}"`
tar xvf "${DATA_FILE}" -C "${DEPS_DATA_DIR}"


## arts from 6.0 we already have it from this job
export DEPS_DATA_DIR="$DEPS_DIR/6.0"
mkdir -p "${DEPS_DATA_DIR}"

mv bootstrap.tar.gz "${DEPS_DATA_DIR}"
mv centos-repo.tar "${DEPS_DATA_DIR}"
mv ubuntu-repo.tar "${DEPS_DATA_DIR}"
mv puppet.tgz "${DEPS_DATA_DIR}"
mv openstack.yaml "${DEPS_DATA_DIR}"
mv version.yaml "${DEPS_DATA_DIR}"
mv fuel-images.tar.lrz "${DEPS_DATA_DIR}"

# building targets
cd ${WORKSPACE}
make centos-diff-repo ubuntu-diff-repo puppet version-yaml openstack-yaml BASE_VERSION=5.1.1


####3.1) preparing diff artifacts for publishing
cd ${ARTS_DIR}
tar cvf "${ARTIFACT_DIFF_NAME}.tar" puppet.tgz version.yaml openstack.yaml diff*


####4) generate upgrade tarball
cd ${ARTS_DIR}

## we already have 5.1.1
#export DEPS_DATA_DIR="$DEPS_DIR/5.1.1"

## arts from 6.0-5.1_diff, we build it one step before
export DEPS_DATA_DIR="$DEPS_DIR/6.0"
# remove previous artifacts (from full job), because for diff we need to put diff-mirrors here
rm -rf "${DEPS_DATA_DIR}"

mkdir -p "${DEPS_DATA_DIR}"

mv diff-* "${DEPS_DATA_DIR}"
mv puppet.tgz "${DEPS_DATA_DIR}"
mv openstack.yaml "${DEPS_DATA_DIR}"
mv version.yaml "${DEPS_DATA_DIR}"

# building targets
cd ${WORKSPACE}
make upgrade-lrzip UPGRADE_VERSIONS="6.0:5.1.1" BASE_VERSION=5.1.1


####5) publish artifacts
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


# Generate build description
ISO_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"