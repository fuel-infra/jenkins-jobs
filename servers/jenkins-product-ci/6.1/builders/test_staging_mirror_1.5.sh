#!/bin/bash

set -ex

# Get the latest mirror and set the mirror id
UBUNTU_MIRROR_URL=$(curl "http://mirror.fuel-infra.org/pkgs/ubuntu-latest.htm")
UBUNTU_MIRROR_ID=$(expr "${UBUNTU_MIRROR_URL}" : '.*/\(ubuntu-.*\)')

# Create artifacts

echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt

# Create properties file for downstream jobs
# artifacts/magnet_link.txt is already available from previous build step

cat ubuntu_mirror_id.txt artifacts/magnet_link.txt > properties_file.txt
echo "BUILD_MIRROR_URL = ${BUILD_MIRROR_URL}" >> properties_file.txt
echo "USE_STABLE_MOS_FOR_STAGING = ${USE_STABLE_MOS_FOR_STAGING}" >> properties_file.txt
