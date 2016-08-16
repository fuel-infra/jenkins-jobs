#!/bin/bash
#
#   :mod: `plugin-env.sh` -- Create snapshot parameters used by tests
#   ==========================================================
#
#   .. module:: plugin-env.sh
#       :platform: Unix
#       :synopsis: Script used to prepare test virtualenv
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Dmitry Kaigarodtsev <dkaiharodsev@mirantis.com>
#
#
#   This script is used to export snapshot parameters on plugin-ci
#
#   .. requirements::
#
#       * label set on the slave
#

set -ex

# default values of variables for 9.0 branch
FUEL_QA_URL=${FUEL_QA_URL:-https://git.openstack.org/openstack/fuel-qa}
MIRROR_HOST=${MIRROR_HOST:-mirror.seed-cz1.fuel-infra.org}
MOS_CENTOS_URL_SUFFIX=${MOS_CENTOS_URL_SUFFIX:-mos-repos/centos/mos9.0-centos7/snapshots}
MOS_UBUNTU_URL_SUFFIX=${MOS_UBUNTU_URL_SUFFIX:-mos-repos/ubuntu/snapshots}
MOS_UBUNTU_BRANCH=${MOS_UBUNTU_BRANCH:-9.0}

# get latest 'fuel-qa' commit
if [[ "${FUEL_QA_COMMIT}" == 'latest' ]]; then
  FUEL_QA_COMMIT=$(git ls-remote "${FUEL_QA_URL}" "${FUEL_QA_BRANCH}" | awk '{print $1}')
fi

# get latest mos ubuntu mirror id
if [[ "${MOS_UBUNTU_MIRROR_ID}" == 'latest' ]]; then
    MOS_UBUNTU_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_UBUNTU_URL_SUFFIX}/${MOS_UBUNTU_BRANCH}-latest.target.txt" \
    | head -1)
fi

# get latest mos centos snapshots by type
if [[ "${MOS_CENTOS_OS_MIRROR_ID}" == 'latest' ]]; then
    TYPE="os"
    MOS_CENTOS_OS_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_CENTOS_URL_SUFFIX}/${TYPE}-latest.target.txt" \
    | head -1)
fi

if [[ "${MOS_CENTOS_PROPOSED_MIRROR_ID}" == 'latest' ]]; then
    TYPE="proposed"
    MOS_CENTOS_PROPOSED_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_CENTOS_URL_SUFFIX}/${TYPE}-latest.target.txt" \
    | head -1)
fi

if [[ "${MOS_CENTOS_UPDATES_MIRROR_ID}" == 'latest' ]]; then
    TYPE="updates"
    MOS_CENTOS_UPDATES_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_CENTOS_URL_SUFFIX}/${TYPE}-latest.target.txt" \
    | head -1)
fi

if [[ "${MOS_CENTOS_HOLDBACK_MIRROR_ID}" == 'latest' ]]; then
    TYPE="holdback"
    MOS_CENTOS_HOLDBACK_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_CENTOS_URL_SUFFIX}/${TYPE}-latest.target.txt" \
    | head -1)
fi

if [[ "${MOS_CENTOS_HOTFIX_MIRROR_ID}" == 'latest' ]]; then
    TYPE="hotfix"
    MOS_CENTOS_HOTFIX_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_CENTOS_URL_SUFFIX}/${TYPE}-latest.target.txt" \
    | head -1)
fi

if [[ "${MOS_CENTOS_SECURITY_MIRROR_ID}" == 'latest' ]]; then
    TYPE="security"
    MOS_CENTOS_SECURITY_MIRROR_ID=$(curl -s \
    "http://${MIRROR_HOST}/${MOS_CENTOS_URL_SUFFIX}/${TYPE}-latest.target.txt" \
    | head -1)
fi

cat > snapshots.params <<SNAPSHOTS_PARAMS
MAGNET_LINK=${MAGNET_LINK}
FUEL_QA_COMMIT=${FUEL_QA_COMMIT}
UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}
CENTOS_MIRROR_ID=${CENTOS_MIRROR_ID}
MOS_UBUNTU_MIRROR_ID=${MOS_UBUNTU_MIRROR_ID}
MOS_CENTOS_OS_MIRROR_ID=${MOS_CENTOS_OS_MIRROR_ID}
MOS_CENTOS_PROPOSED_MIRROR_ID=${MOS_CENTOS_PROPOSED_MIRROR_ID}
MOS_CENTOS_UPDATES_MIRROR_ID=${MOS_CENTOS_UPDATES_MIRROR_ID}
MOS_CENTOS_HOLDBACK_MIRROR_ID=${MOS_CENTOS_HOLDBACK_MIRROR_ID}
MOS_CENTOS_HOTFIX_MIRROR_ID=${MOS_CENTOS_HOTFIX_MIRROR_ID}
MOS_CENTOS_SECURITY_MIRROR_ID=${MOS_CENTOS_SECURITY_MIRROR_ID}
SNAPSHOTS_PARAMS
