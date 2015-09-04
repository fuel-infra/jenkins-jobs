#!/bin/bash

set -ex

# Get Ubuntu mirror url and id

if [ "${UBUNTU_MIRROR_ID}" == 'latest' ]
then
    # Get the latest mirror and set the mirror id
    UBUNTU_MIRROR_URL=$(curl "http://mirror-pkgs.vm.mirantis.net/ubuntu-latest.htm")
    UBUNTU_MIRROR_ID=$(expr "${UBUNTU_MIRROR_URL}" : '.*/\(ubuntu-.*\)')
else
    # Don't change mirror id, set mirror url only
    UBUNTU_MIRROR_URL="http://mirror-pkgs.vm.mirantis.net/${UBUNTU_MIRROR_ID}"
fi

# Get the real build number from the lastSuccessfulBuild link

REAL_UPSTREAM_BUILD_NUMBER=$(curl "${UPSTREAM_JOB_URL}${UPSTREAM_BUILD_NUMBER}/buildNumber")
UPSTREAM_BUILD_URL="${UPSTREAM_JOB_URL}${REAL_UPSTREAM_BUILD_NUMBER}/"

# Create pretty description from UPSTREAM_JOB_URL and UPSTREAM_BUILD_NUMBER variables

echo "Description string: <a href=\"${UPSTREAM_BUILD_URL}\">ISO ${REAL_UPSTREAM_BUILD_NUMBER}</a>"

# Create artifacts

echo "ISO_BUILD_URL=${UPSTREAM_BUILD_URL}" > iso_build_url.txt
echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt

curl "${UPSTREAM_BUILD_URL}artifact/magnet_link.txt" -o magnet_link.txt

# Create properties file for downstream jobs

cat ubuntu_mirror_id.txt magnet_link.txt > properties_file.txt
