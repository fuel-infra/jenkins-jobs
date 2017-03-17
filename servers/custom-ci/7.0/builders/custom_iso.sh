#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

PROD_VER=$(grep 'PRODUCT_VERSION:=' config.mk | cut -d= -f2)

export ISO_NAME="fuel-gerrit-${PROD_VER}-${BUILD_NUMBER}-${BUILD_ID}"
export UPGRADE_TARBALL_NAME="fuel-gerrit-${PROD_VER}-upgrade-${BUILD_NUMBER}-${BUILD_ID}"

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${WORKSPACE}/artifacts"
rm -rf "${ARTS_DIR}"

export DEPS_DIR="${BUILD_DIR}/deps"
rm -rf "${DEPS_DIR}"

# Checking gerrit commits for fuel-main
if [ "${FUELMAIN_COMMIT}" != "stable/7.0" ] ; then
    git checkout "${FUELMAIN_COMMIT}"
fi

# Checking gerrit commits for fuel-main
if [ "${fuelmain_gerrit_commit}" != "none" ] ; then
  for commit in ${fuelmain_gerrit_commit} ; do
    # shellcheck disable=SC2015
    git fetch https://review.openstack.org/openstack/fuel-main "${commit}" && git cherry-pick FETCH_HEAD || false
  done
fi

export NAILGUN_GERRIT_COMMIT="${nailgun_gerrit_commit}"
export ASTUTE_GERRIT_COMMIT="${astute_gerrit_commit}"
export OSTF_GERRIT_COMMIT="${ostf_gerrit_commit}"
export FUELLIB_GERRIT_COMMIT="${fuellib_gerrit_commit}"
export PYTHON_FUELCLIENT_GERRIT_COMMIT="${python_fuelclient_gerrit_commit}"
export FUEL_AGENT_GERRIT_COMMIT="${fuel_agent_gerrit_commit}"
export FUEL_NAILGUN_AGENT_GERRIT_COMMIT="${fuel_nailgun_agent_gerrit_commit}"

######## Get node location to choose closer mirror ###############
# Do NOTHING if USE_MIRROR=none, else if user choose auto, we try to use
# facter location to get closer mirror, if user provide the exact mirror we
# use it
if [ "${USE_MIRROR}" != "none" ]; then

  if [ "${USE_MIRROR}" == "auto" ]; then
    LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
    LOCATION=${LOCATION_FACT:-msk}
  else
    LOCATION="${USE_MIRROR}"
  fi

  case "${LOCATION}" in
      poz|bud|bud-ext|cz|undef)
          USE_MIRROR=cz
          LATEST_MIRROR_ID_URL=http://mirror.seed-cz1.fuel-infra.org
          ;;
      mnv|scc|sccext)
          USE_MIRROR=usa
          LATEST_MIRROR_ID_URL=http://mirror.seed-us1.fuel-infra.org
          ;;
      *)
          USE_MIRROR=cz
          LATEST_MIRROR_ID_URL=http://mirror.seed-cz1.fuel-infra.org
  esac

  LATEST_TARGET=$(curl -sSf "${LATEST_MIRROR_ID_URL}/mos-repos/ubuntu/7.0.target.txt" | sed '1p; d')
  export MIRROR_MOS_UBUNTU_ROOT="/mos-repos/ubuntu/${LATEST_TARGET}"
fi

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU_ROOT}"

#########################################

echo "STEP 0. Clean before start"
make deep_clean

#########################################

echo "STEP 1. Make everything"
echo "ENV VARIABLES START"
printenv
echo "ENV VARIABLES END"

# should be word splitted
# shellcheck disable=SC2086
make $make_args iso version-yaml

#########################################

echo "STEP 2. Publish everything"

cd "${ARTS_DIR}"
# shellcheck disable=SC2045
for artifact in $(ls fuel-*)
do
  "${WORKSPACE}/utils/jenkins/process_artifacts.sh" "${artifact}"
done

cd "${WORKSPACE}"

cat > "${ARTS_DIR}/gerrit_commits.txt" <<EOF
FUELMAIN_GERRIT_COMMIT=${fuelmain_gerrit_commit}
NAILGUN_GERRIT_COMMIT=${nailgun_gerrit_commit}
ASTUTE_GERRIT_COMMIT=${astute_gerrit_commit}
OSTF_GERRIT_COMMIT=${ostf_gerrit_commit}
FUELLIB_GERRIT_COMMIT=${fuellib_gerrit_commit}
PYTHON_FUELCLIENT_GERRIT_COMMIT=${python_fuelclient_gerrit_commit}
FUEL_AGENT_GERRIT_COMMIT=${fuel_agent_gerrit_commit}
FUEL_NAILGUN_AGENT_GERRIT_COMMIT=${fuel_nailgun_agent_gerrit_commit}
EOF

# let's save fuel-centos-build.log as artifact
gzip -c "${BUILD_DIR}/docker/fuel-centos-build.log" > "${ARTS_DIR}/fuel-centos-build.log.gz" || true

cp "${LOCAL_MIRROR}"/*changelog "${ARTS_DIR}/" || true
cp "${BUILD_DIR}/iso/isoroot/version.yaml" "${ARTS_DIR}/version.yaml.txt" || true
(cd "${BUILD_DIR}/iso/isoroot" && find . | sed -s 's/\.\///') > "${ARTS_DIR}/listing.txt" || true

grep MAGNET_LINK "${ARTS_DIR}"/*iso.data.txt > "${ARTS_DIR}/magnet_link.txt"

# Generate build description
ISO_MAGNET_LINK=$(grep MAGNET_LINK "${ARTS_DIR}"/*iso.data.txt | sed 's/MAGNET_LINK=//')
ISO_HTTP_LINK=$(grep HTTP_LINK "${ARTS_DIR}"/*iso.data.txt | sed 's/HTTP_LINK=//')
ISO_HTTP_TORRENT=$(grep HTTP_TORRENT "${ARTS_DIR}"/*iso.data.txt | sed 's/HTTP_TORRENT=//')

echo "<a href=${ISO_HTTP_LINK}>ISO download link</a> <a href=${ISO_HTTP_TORRENT}>ISO torrent link</a><br>${ISO_MAGNET_LINK}<br>"

#########################################

echo "STEP 3. Clean after build"
make deep_clean

#########################################
