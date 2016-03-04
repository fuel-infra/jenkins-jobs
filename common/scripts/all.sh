#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

PROD_VER=$(grep '^PRODUCT_VERSION' config.mk | cut -d= -f2)

export PRODUCT_VERSION="$PROD_VER"
export ISO_NAME="fuel-${ISO_ID}-${BUILD_NUMBER}-${BUILD_TIMESTAMP}"

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${WORKSPACE}/artifacts"
rm -rf "${ARTS_DIR}"
mkdir -p "${ARTS_DIR}"

############### Get MIRROR URLs ###############

# 1. Define closest mirror based on server location

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    srt)
        CLOSEST_MIRROR_URL="http://osci-mirror-srt.srt.mirantis.net"
        ;;
    msk)
        CLOSEST_MIRROR_URL="http://osci-mirror-msk.msk.mirantis.net"
        ;;
    hrk)
        CLOSEST_MIRROR_URL="http://osci-mirror-kha.kha.mirantis.net"
        ;;
    poz|bud|bud-ext|cz)
        CLOSEST_MIRROR_URL="http://mirror.seed-cz1.fuel-infra.org"
        ;;
    scc)
        CLOSEST_MIRROR_URL="http://mirror.seed-us1.fuel-infra.org"
        ;;
    *)
        CLOSEST_MIRROR_URL="http://osci-mirror-msk.msk.mirantis.net"
esac

# 2. Get Upstream Ubuntu mirror snapshot

if [ "${UBUNTU_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror and set the mirror id
    UBUNTU_MIRROR_URL=$(curl "${CLOSEST_MIRROR_URL}/pkgs/ubuntu-latest.htm")
    UBUNTU_MIRROR_ID=$(expr "${UBUNTU_MIRROR_URL}" : '.*/\(ubuntu-.*\)')
fi

# make system uses both MIRROR_UBUNTU and MIRROR_UBUNTU_ROOT
# parameters and concatenates them

export MIRROR_UBUNTU="${CLOSEST_MIRROR_URL#http://}"
export MIRROR_UBUNTU_ROOT="/pkgs/${UBUNTU_MIRROR_ID}"

echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > "${ARTS_DIR}/ubuntu_mirror_id.txt"

# 3. Get MOS Ubuntu mirror snapshot

export MIRROR_MOS_UBUNTU="${CLOSEST_MIRROR_URL#http://}"
LATEST_TARGET_MOS_UBUNTU=$(curl -sSf "http://${MIRROR_MOS_UBUNTU}/${MOS_UBUNTU_ROOT}/${MOS_UBUNTU_TARGET}" | head -1)
export MIRROR_MOS_UBUNTU_ROOT="${MOS_UBUNTU_ROOT}/${LATEST_TARGET_MOS_UBUNTU}"

echo "MOS_UBUNTU_MIRROR_ID=${LATEST_TARGET_MOS_UBUNTU}" > "${ARTS_DIR}/mos_ubuntu_mirror_id.txt"

# 4. Get Upstream CentOS mirror snapshot

if [ "${CENTOS_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror and set the mirror id
    CENTOS_MIRROR_URL=$(curl "${CLOSEST_MIRROR_URL}/pkgs/centos-latest.htm")
    CENTOS_MIRROR_ID=$(expr "${CENTOS_MIRROR_URL}" : '.*/\(centos-.*\)')
fi

MIRROR_CENTOS_ROOT="pkgs/${CENTOS_MIRROR_ID}"

# make system uses MIRROR_CENTOS parameter directly

export MIRROR_CENTOS="${CLOSEST_MIRROR_URL}/${MIRROR_CENTOS_ROOT}"

echo "CENTOS_MIRROR_ID=${CENTOS_MIRROR_ID}" > "${ARTS_DIR}/centos_mirror_id.txt"

# 5. Get MOS CentOS mirror (Fuel) snapshot

LATEST_TARGET_MOS_CENTOS=$(curl -sSf "${CLOSEST_MIRROR_URL}/${MOS_CENTOS_ROOT}/os.target.txt" | head -1)
export MIRROR_FUEL="${CLOSEST_MIRROR_URL}/${MOS_CENTOS_ROOT}/${LATEST_TARGET_MOS_CENTOS}/x86_64"

echo "MOS_CENTOS_MIRROR_ID=${LATEST_TARGET_MOS_CENTOS}" > "${ARTS_DIR}/mos_centos_mirror_id.txt"

############### Done defining mirrors ###############

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU}${MIRROR_MOS_UBUNTU_ROOT} and ${MIRROR_FUEL}"

process_artifacts() {
    local ARTIFACT="$1"
    test -f "$ARTIFACT" || return 1

    local HOSTNAME=$(hostname -f)
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
    local MAGNET_LINK=$(seedclient.py -v -u -f "$LOCAL_STORAGE"/"$ARTIFACT" --tracker-url="${TRACKER_URL}" --http-root="${HTTP_ROOT}" || true)
    local STORAGES=($(echo "${HTTP_ROOT}" | tr ',' '\n'))
    local HTTP_LINK="${STORAGES}/${ARTIFACT}"
    local HTTP_TORRENT="${HTTP_LINK}.torrent"

    cat > $ARTIFACT.data.txt <<EOF
ARTIFACT=$ARTIFACT
HTTP_LINK=$HTTP_LINK
HTTP_TORRENT=$HTTP_TORRENT
MAGNET_LINK=$MAGNET_LINK
EOF

}

#########################################

echo "STEP 0. Clean before start"
make deep_clean

rm -rf /var/tmp/yum-${USER}-*

#########################################

echo "STEP 1. Make everything"

make $make_args iso listing

#########################################

echo "STEP 2. Publish everything"

export LOCAL_STORAGE='/var/www/fuelweb-iso'
export HTTP_ROOT="http://$(hostname -f)/fuelweb-iso"
export TRACKER_URL='http://tracker01-bud.infra.mirantis.net:8080/announce,http://tracker01-scc.infra.mirantis.net:8080/announce,http://tracker01-msk.infra.mirantis.net:8080/announce'

cd "${ARTS_DIR}"
for artifact in $(ls fuel-*)
do
  process_artifacts $artifact $LOCAL_STORAGE $TRACKER_URL $HTTP_ROOT
done

cp "${LOCAL_MIRROR}"/*changelog "${ARTS_DIR}/" || true
cp "${BUILD_DIR}/listing-build.txt" "${ARTS_DIR}/listing-build.txt" || true
cp "${BUILD_DIR}/listing-local-mirror.txt" "${ARTS_DIR}/listing-local-mirror.txt" || true
cp "${BUILD_DIR}/listing-package-changelog.txt" "${ARTS_DIR}/listing-package-changelog.txt" || true
(cd "${BUILD_DIR}/iso/isoroot" && find . | sed -s 's/\.\///') > "${ARTS_DIR}/listing.txt" || true

grep MAGNET_LINK "${ARTS_DIR}"/*iso.data.txt > "${ARTS_DIR}/magnet_link.txt"

# Generate build description
ISO_MAGNET_LINK=$(grep MAGNET_LINK "${ARTS_DIR}"/*iso.data.txt | sed 's/MAGNET_LINK=//')
ISO_HTTP_LINK=$(grep HTTP_LINK "${ARTS_DIR}"/*iso.data.txt | sed 's/HTTP_LINK=//')
ISO_HTTP_TORRENT=$(grep HTTP_TORRENT "${ARTS_DIR}"/*iso.data.txt | sed 's/HTTP_TORRENT=//')

echo "<a href=${ISO_HTTP_LINK}>ISO download link</a> <a href=${ISO_HTTP_TORRENT}>ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"

#########################################

echo "STEP 3. Clean after build"

cd ${WORKSPACE}

make deep_clean

#########################################
