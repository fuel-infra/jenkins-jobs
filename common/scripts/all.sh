#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

export ISO_NAME="fuel-${ISO_ID}-${BUILD_NUMBER}-${BUILD_TIMESTAMP}"

export BUILD_DIR="${WORKSPACE}/../tmp/${JOB_NAME}/build"
export LOCAL_MIRROR="${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror"

export ARTS_DIR="${ARTS_DIR:-${WORKSPACE}/artifacts}"
rm -rf "${ARTS_DIR}"
mkdir -p "${ARTS_DIR}"

############
# CUSTOM ISO
############
if [ "${ISO_TYPE}" = "custom" ]; then
  export DEPS_DIR="${BUILD_DIR}/deps"
  rm -rf "${DEPS_DIR}"

  # Checking gerrit commits for fuel-main
  if [ "${FUELMAIN_COMMIT}" != "master" ] ; then
      git checkout "${FUELMAIN_COMMIT}"
  fi

  # Checking gerrit commits for fuel-main
  if [ "${FUELMAIN_GERRIT_COMMIT}" != "none" ] ; then
    for commit in ${FUELMAIN_GERRIT_COMMIT} ; do
      # shellcheck disable=SC2015
      git fetch https://review.openstack.org/openstack/fuel-main "${commit}" && \
          git cherry-pick FETCH_HEAD || false
    done
  fi
fi
############

############### Get MIRROR URLs ###############

# 1. Define closest mirror based on server location

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

if [ -z "${CLOSEST_MIRROR_URL}" ]; then
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
        poz|bud|budext|cz)
            CLOSEST_MIRROR_URL="http://mirror.seed-cz1.fuel-infra.org"
            ;;
        scc)
            CLOSEST_MIRROR_URL="http://mirror.seed-us1.fuel-infra.org"
            ;;
        *)
            CLOSEST_MIRROR_URL="http://mirror.fuel-infra.org"
    esac
fi

# 2. Get Upstream Ubuntu mirror snapshot

if [ "${UBUNTU_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror and set the mirror id
    UBUNTU_MIRROR_URL=$(curl -sSf "${CLOSEST_MIRROR_URL}/pkgs/ubuntu-latest.htm")
    UBUNTU_MIRROR_ID=$(expr "${UBUNTU_MIRROR_URL}" : '.*/\(ubuntu-.*\)')
fi

# make system uses both MIRROR_UBUNTU and MIRROR_UBUNTU_ROOT
# parameters and concatenates them

export MIRROR_UBUNTU=${MIRROR_UBUNTU:-"${CLOSEST_MIRROR_URL#http://}"}
export MIRROR_UBUNTU_ROOT=${MIRROR_UBUNTU_ROOT:-"/pkgs/${UBUNTU_MIRROR_ID}"}

echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > "${ARTS_DIR}/ubuntu_mirror_id.txt"

# 3. Get MOS Ubuntu mirror snapshot

if [[ "${make_args}" != *"MIRROR_MOS_UBUNTU="* ]]; then
    # MIRROR_MOS_UBUNTU= is not defined in make_args, so let's use the default one
    # since in fuel-main MIRROR_MOS_UBUNTU?=perestroika-repo-tst.infra.mirantis.net, we need to remove http://
    export MIRROR_MOS_UBUNTU="${CLOSEST_MIRROR_URL#http://}"
    LATEST_TARGET_MOS_UBUNTU=$(curl -sSf "http://${MIRROR_MOS_UBUNTU}/${MOS_UBUNTU_ROOT}/${MOS_UBUNTU_TARGET}" | head -1)
    export MIRROR_MOS_UBUNTU_ROOT="${MOS_UBUNTU_ROOT}/${LATEST_TARGET_MOS_UBUNTU}"

    echo "MOS_UBUNTU_MIRROR_ID=${LATEST_TARGET_MOS_UBUNTU}" > "${ARTS_DIR}/mos_ubuntu_mirror_id.txt"
fi

# 4. Get Upstream CentOS mirror snapshot

if [ "${CENTOS_MIRROR_ID}" == 'centos-7.2.1511' ]
then
    # Get the latest mirror and set the mirror id
    CENTOS_MIRROR_URL=$(curl -sSf "${CLOSEST_MIRROR_URL}/pkgs/centos-7.2.1511-latest.htm")
    CENTOS_MIRROR_ID=$(expr "${CENTOS_MIRROR_URL}" : '.*/\(centos-.*\)')
fi

MIRROR_CENTOS_ROOT="pkgs/snapshots/${CENTOS_MIRROR_ID}"

# make system uses MIRROR_CENTOS parameter directly

export MIRROR_CENTOS="${CLOSEST_MIRROR_URL}/${MIRROR_CENTOS_ROOT}"

echo "CENTOS_MIRROR_ID=${CENTOS_MIRROR_ID}" > "${ARTS_DIR}/centos_mirror_id.txt"

# 5. Get MOS CentOS mirror (Fuel) snapshot

LATEST_TARGET_MOS_CENTOS=$(curl -sSf "${CLOSEST_MIRROR_URL}/${MOS_CENTOS_ROOT}/os.target.txt" | head -1)

# we need to have ability to define MIRROR_FUEL by user
if [[ "${make_args}" != *"MIRROR_FUEL="* ]]; then
    # MIRROR_FUEL= is not defined in make_args so let's
    # define the closest stable centos mirror snapshot
    # http://perestroika-repo-tst.infra.mirantis.net/mos-repos/centos/$(PRODUCT_NAME)$(PRODUCT_VERSION)-centos7/os/x86_64
    export MIRROR_FUEL="${CLOSEST_MIRROR_URL}/${MOS_CENTOS_ROOT}/${LATEST_TARGET_MOS_CENTOS}/x86_64"

    echo "MOS_CENTOS_MIRROR_ID=${LATEST_TARGET_MOS_CENTOS}" > "${ARTS_DIR}/mos_centos_mirror_id.txt"
fi

############### Done defining mirrors ###############

echo "Using mirror: ${USE_MIRROR} with ${MIRROR_MOS_UBUNTU}${MIRROR_MOS_UBUNTU_ROOT} and ${MIRROR_FUEL}"

#########################################

echo "STEP 0. Clean before start"
make deep_clean

rm -rf "/var/tmp/yum-${USER}"-*

#########################################

echo "STEP 1. Make everything"
############
# CUSTOM ISO
############
if [ "${ISO_TYPE}" = "custom" ]; then
    echo "ENV VARIABLES START"
    printenv
    echo "ENV VARIABLES END"
fi
############
# shellcheck disable=SC2086
make $make_args iso listing

#########################################

echo "STEP 2. Publish everything"

cp "${LOCAL_MIRROR}"/*changelog "${ARTS_DIR}/" || true
cp "${BUILD_DIR}/listing-package-changelog.txt" "${ARTS_DIR}/listing-package-changelog.txt" || true
(cd "${BUILD_DIR}/iso/isoroot" && find . | sed -s 's/\.\///') > "${ARTS_DIR}/listing.txt" || true

############
# CUSTOM ISO
############
if [ "${ISO_TYPE}" = "custom" ]; then
cat > "${ARTS_DIR}/gerrit_commits.txt" <<GERRITCOMMITVALUES
FUELMAIN_GERRIT_COMMIT="${FUELMAIN_GERRIT_COMMIT}"
NAILGUN_GERRIT_COMMIT="${NAILGUN_GERRIT_COMMIT}"
ASTUTE_GERRIT_COMMIT="${ASTUTE_GERRIT_COMMIT}"
OSTF_GERRIT_COMMIT="${OSTF_GERRIT_COMMIT}"
FUELLIB_GERRIT_COMMIT="${FUELLIB_GERRIT_COMMIT}"
PYTHON_FUELCLIENT_GERRIT_COMMIT="${PYTHON_FUELCLIENT_GERRIT_COMMIT}"
FUEL_AGENT_GERRIT_COMMIT="${FUEL_AGENT_GERRIT_COMMIT}"
FUEL_NAILGUN_AGENT_GERRIT_COMMIT="${FUEL_NAILGUN_AGENT_GERRIT_COMMIT}"
FUEL_MIRROR_GERRIT_COMMIT="${FUEL_MIRROR_GERRIT_COMMIT}"
FUELMENU_GERRIT_COMMIT="${FUELMENU_GERRIT_COMMIT}"
SHOTGUN_GERRIT_COMMIT="${SHOTGUN_GERRIT_COMMIT}"
NETWORKCHECKER_GERRIT_COMMIT="${NETWORKCHECKER_GERRIT_COMMIT}"
FUELUPGRADE_GERRIT_COMMIT="${FUELUPGRADE_GERRIT_COMMIT}"
FUEL_UI_GERRIT_COMMIT="${FUEL_UI_GERRIT_COMMIT}"
GERRITCOMMITVALUES
fi
############

#########################################

echo "STEP 3. Clean after build"

cd "${WORKSPACE}"

make deep_clean

#########################################
