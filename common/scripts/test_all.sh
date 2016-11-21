#!/bin/bash

set -ex

# Get Ubuntu mirror url and id

if [ "${UBUNTU_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror id
    UBUNTU_MIRROR_ID=$(curl -sSf "http://mirror.fuel-infra.org/pkgs/snapshots/ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
fi

# Get the real build number from the lastSuccessfulBuild link

REAL_UPSTREAM_BUILD_NUMBER=$(curl "${UPSTREAM_JOB_URL}${UPSTREAM_BUILD_NUMBER}/buildNumber")
UPSTREAM_BUILD_URL="${UPSTREAM_JOB_URL}${REAL_UPSTREAM_BUILD_NUMBER}/"

# Get last git commit in $FUEL_QA_BRANCH for bvt and smoke tests
# $FUEL_QA_BRANCH - git branch in bvt and smoke jobs
FUEL_QA_COMMIT=$(git ls-remote https://git.openstack.org/openstack/fuel-qa.git "refs/heads/${FUEL_QA_BRANCH}" | cut -f 1)

# Create pretty description from UPSTREAM_JOB_URL and UPSTREAM_BUILD_NUMBER variables

echo "Description string: <a href=\"${UPSTREAM_BUILD_URL}\">ISO ${REAL_UPSTREAM_BUILD_NUMBER}</a>"

# Create artifacts

echo "ISO_BUILD_URL=${UPSTREAM_BUILD_URL}" > iso_build_url.txt
echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt
echo "FUEL_QA_COMMIT=${FUEL_QA_COMMIT}" > fuel_qa_commit.txt

curl "${UPSTREAM_BUILD_URL}artifact/artifacts/magnet_link.txt" -o magnet_link.txt

# Create properties file for downstream jobs

cat ubuntu_mirror_id.txt magnet_link.txt fuel_qa_commit.txt > properties_file.txt
