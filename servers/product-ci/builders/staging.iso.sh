set -x

# Checking gerrit commits for fuel-main
if [ "$FUELMAIN_COMMIT" != "master" ] ; then
    git checkout $FUELMAIN_COMMIT
fi

PROD_VER=`grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2`

export LANG="C"
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

export ISO_NAME=fuel-staging-$PROD_VER-$BUILD_NUMBER-$BUILD_ID
export UPGRADE_TARBALL_NAME=fuel-staging-$PROD_VER-upgrade-$BUILD_NUMBER-$BUILD_ID

export BUILD_DIR=../tmp/$(basename $(pwd))/build
export LOCAL_MIRROR=../tmp/$(basename $(pwd))/local_mirror
export ARTS_DIR=${WORKSPACE}/artifacts

# Checking gerrit commits for fuel-main
if [ "$fuelmain_gerrit_commit" != "none" ] ; then
  for commit in $fuelmain_gerrit_commit ; do
    git fetch https://review.openstack.org/stackforge/fuel-main $commit && git cherry-pick FETCH_HEAD || false
  done
fi

export NAILGUN_GERRIT_COMMIT="$nailgun_gerrit_commit"
export ASTUTE_GERRIT_COMMIT="$astute_gerrit_commit"
export OSTF_GERRIT_COMMIT="$ostf_gerrit_commit"
export FUELLIB_GERRIT_COMMIT="$fuellib_gerrit_commit"

make deep_clean

# Add patching data support

if [ "$PATCHING_DATA" ] && [ "$PATCHING_DATA" != "none" ]; then
  export DEPS_DIR='objects'
  export DEPS_DATA_DIR="$DEPS_DIR/5.0.x"
  mkdir -p "${DEPS_DATA_DIR}"
  if [ "$PATCHING_DATA" == "latest" ]; then
    DATA_MAGNET_LINK=`curl -s 'http://jenkins-product.srt.mirantis.net:8080/job/fuel_5_0_2_iso/lastSuccessfulBuild/artifact/data_magnet_link.txt' | fgrep patching-data | sed 's~.*MAGNET_LINK=~~'`
  else
    DATA_MAGNET_LINK=${PATCHING_DATA}
  fi
  DATA_FILE=`seedclient-wrapper -dvm "${DATA_MAGNET_LINK}" --force-set-symlink -o "${DEPS_DATA_DIR}"`
  tar xvf "${DATA_FILE}" -C "${DEPS_DATA_DIR}"
  add_make_target='upgrade-lrzip'
fi

make $make_args iso img version-yaml $add_make_target

cd ${ARTS_DIR}

for artifact in `ls fuel-*`
do
 ../utils/jenkins/process_artifacts.sh $artifact
done

cd $WORKSPACE

echo FUELMAIN_GERRIT_COMMIT="$fuelmain_gerrit_commit" > artifacts/gerrit_commits.txt
echo NAILGUN_GERRIT_COMMIT="$nailgun_gerrit_commit" >> artifacts/gerrit_commits.txt
echo ASTUTE_GERRIT_COMMIT="$astute_gerrit_commit" >> artifacts/gerrit_commits.txt
echo OSTF_GERRIT_COMMIT="$ostf_gerrit_commit" >> artifacts/gerrit_commits.txt
echo FUELLIB_GERRIT_COMMIT="$fuellib_gerrit_commit" >> artifacts/gerrit_commits.txt

cp $LOCAL_MIRROR/*changelog ${ARTS_DIR}/ || true
cp ${BUILD_DIR}/iso/isoroot/version.yaml ${ARTS_DIR}/version.yaml.txt || true
(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${ARTS_DIR}/listing.txt || true

grep MAGNET_LINK $ARTS_DIR/*iso.data.txt > ${ARTS_DIR}/magnet_link.txt

# Generate build description
ISO_MAGNET_LINK=`grep MAGNET_LINK $ARTS_DIR/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK $ARTS_DIR/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT $ARTS_DIR/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"
