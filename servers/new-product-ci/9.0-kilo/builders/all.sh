#!/bin/bash

set -ex

export FEATURE_GROUPS="mirantis"

PROD_VER=$(grep '^PRODUCT_VERSION' config.mk | cut -d= -f2)
export ISO_NAME=fuel-$PROD_VER-kilo-$BUILD_NUMBER-${BUILD_TIMESTAMP}

export BUILD_DIR=${WORKSPACE}/../tmp/${JOB_NAME}/build
export LOCAL_MIRROR=${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror

export ARTS_DIR=${WORKSPACE}/artifacts
rm -rf ${ARTS_DIR}

#########################################

test "$deep_clean" = "true" && make deep_clean

#########################################

echo "STEP 0. Export path to MOS kilo"
export MIRROR_MOS_UBUNTU="perestroika-repo-tst.infra.mirantis.net"
export MIRROR_MOS_UBUNTU_ROOT="/mos-repos/ubuntu/9.0-kilo/"
export MIRROR_MOS_UBUNTU_SUITE="mos9.0-kilo"
export MIRROR_FUEL="http://perestroika-repo-tst.infra.mirantis.net/mos-repos/centos/mos9.0-centos7/os/x86_64"
export MIRROR_UBUNTU="mirror.seed-cz1.fuel-infra.org"
export USE_MIRROR=none

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU_ROOT}"


process_artifacts() {
    local ARTIFACT="$1"
    test -f "$ARTIFACT" || return 1

    local HOSTNAME=`hostname -f`
    local LOCAL_STORAGE="$2"
    local TRACKER_URL="$3"
    local HTTP_ROOT="$4"

    echo "MD5SUM is:"
    md5sum $ARTIFACT

    echo "SHA1SUM is:"
    sha1sum $ARTIFACT

    mkdir -p $LOCAL_STORAGE
    mv $ARTIFACT $LOCAL_STORAGE

    # seedclient.py comes from python-seed devops package
    local MAGNET_LINK=`seedclient.py -v -u -f "$LOCAL_STORAGE"/"$ARTIFACT" --tracker-url="${TRACKER_URL}" --http-root="${HTTP_ROOT}" || true`
    local STORAGES=($(echo "${HTTP_ROOT}" | tr ',' '\n'))
    local HTTP_LINK="${STORAGES}/${ARTIFACT}"
    local HTTP_TORRENT="${HTTP_LINK}.torrent"

    cat > $ARTIFACT.data.txt <<EOF
ARTIFACT=$ARTIFACT
HTTP_LINK=$HTTP_LINK
HTTP_TORRENT=$HTTP_TORRENT
MAGNET_LINK=$MAGNET_LINK
EOF

    cat >$ARTIFACT.data.html <<EOF
<h1>$ARTIFACT</h1>
<a href=\"$HTTP_LINK\">HTTP link</a><br>
<a href=\"$HTTP_TORRENT\">Torrent file</a><br>
<a href=\"$MAGNET_LINK\">Magnet link</a><br>
EOF

}

#########################################

echo "STEP 1. Make everything"
make ${make_args} iso listing

#########################################

echo "STEP 2. Publish everything"

export LOCAL_STORAGE='/var/www/fuelweb-iso'
export HTTP_ROOT="http://`hostname -f`/fuelweb-iso"
export TRACKER_URL='http://tracker01-bud.infra.mirantis.net:8080/announce,http://tracker01-scc.infra.mirantis.net:8080/announce,http://tracker01-msk.infra.mirantis.net:8080/announce'

cd ${ARTS_DIR}
for artifact in `ls fuel-*`
do
  begin=`date +%s`
  process_artifacts $artifact $LOCAL_STORAGE $TRACKER_URL $HTTP_ROOT
  echo "Time taken: $((`date +%s` - $begin))"
done

cd ${WORKSPACE}

cp $LOCAL_MIRROR/*changelog ${ARTS_DIR}/ || true
cp ${BUILD_DIR}/listing-package-changelog.txt ${WORKSPACE}/listing-package-changelog.txt || true
(cd ${BUILD_DIR}/iso/isoroot && find . | sed -s 's/\.\///') > ${WORKSPACE}/listing.txt || true

grep MAGNET_LINK ${ARTS_DIR}/fuel-*.iso.data.txt > ${WORKSPACE}/magnet_link.txt

#########################################

echo "STEP 3. Generate build description"

ISO_MAGNET_LINK=`grep MAGNET_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/MAGNET_LINK=//'`
ISO_HTTP_LINK=`grep HTTP_LINK ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_LINK=//'`
ISO_HTTP_TORRENT=`grep HTTP_TORRENT ${ARTS_DIR}/*iso.data.txt | sed 's/HTTP_TORRENT=//'`

echo "<a href="$ISO_HTTP_LINK">ISO download link</a> <a href="$ISO_HTTP_TORRENT">ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"

if [ "${trigger_community_build}" = "true" ]; then
  curl -X POST https://ci.fuel-infra.org/job/${PROD_VER}-community.all/buildWithParameters \
  --user product-ci:${FUEL_CI_API_TOKEN}
fi

echo "BUILD FINISHED."
