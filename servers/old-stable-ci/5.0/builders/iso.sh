export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

release=5.0.3

export FUELLIB_REPO=https://github.com/openstack/fuel-library.git
export NAILGUN_REPO=https://github.com/openstack/fuel-web.git
export ASTUTE_REPO=https://github.com/openstack/fuel-astute.git
export OSTF_REPO=https://github.com/openstack/fuel-ostf.git
export FUELMAIN_REPO=https://github.com/openstack/fuel-main.git

# Available choises: msk srt usa hrk none
export USE_MIRROR=msk

# Space separated additional rpm repo list. Format: "reponame1,url_for_repo1 reponame2,url_for_repo2"
export EXTRA_RPM_REPOS=''

# Additional deb repo list. Format: "url1 precise main|url2 precise/main"
export EXTRA_DEB_REPOS=''

# Which ISO to build - either with docker containers or without. Anything not equal to "docker" will disable containers
export PRODUCTION=docker

# Whether to download or rebuild docker containers from scratch. 0 means to build, 1 means to download
export DOCKER_PREBUILT=0

export MIRANTIS=yes # legacy
export FEATURE_GROUPS=mirantis

# define iso artifact name
export ISO_NAME=fuel-$release-$BUILD_NUMBER-$BUILD_TIMESTAMP

# define place for building artifacts
export BUILD_DIR=${WORKSPACE}/../tmp/${JOB_NAME}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

# ensure we clean artifacts and deps dir on deep_clean
export ARTIFACTS_DIR=${BUILD_DIR}/artifacts
export DEPS_DIR=${BUILD_DIR}/deps

# clean before make
make deep_clean

# we need to have iso img and NO other targets
make iso img

export LOCAL_STORAGE='/var/www/fuelweb-iso'
export HTTP_ROOT="http://`hostname -f`/fuelweb-iso"

cd ${ARTIFACTS_DIR}

for artifact in `ls | grep -v yaml`
do
 ${WORKSPACE}/utils/jenkins/process_artifacts.sh $artifact
done

# save magnet link to ISO as artifact
grep MAGNET_LINK $ARTIFACTS_DIR/*iso.data.txt > $WORKSPACE/magnet_link.txt

# Generate build description
ISO_MAGNET_LINK=`grep MAGNET_LINK $ARTIFACTS_DIR/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK $ARTIFACTS_DIR/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT $ARTIFACTS_DIR/*iso.data.txt | sed 's/HTTP_TORRENT=//'`
echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"


cp ${BUILD_DIR}/iso/isoroot/version.yaml $WORKSPACE/version.yaml.txt || true
