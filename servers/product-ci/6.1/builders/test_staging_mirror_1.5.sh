#!/bin/bash

set -ex

# Get the latest mirror and set the mirror id
UBUNTU_MIRROR_URL=$(curl "http://mirror-pkgs.vm.mirantis.net/ubuntu-latest.htm")
UBUNTU_MIRROR_ID=$(expr "${UBUNTU_MIRROR_URL}" : '.*/\(ubuntu-.*\)')

# Create artifacts

echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt

# FIXME: this is hardcoded url passed to all downstream tests. In
# future we should pass only the mirror id and full url should be
# determined according to server location.
echo "MIRROR_UBUNTU=deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse" > mirror_ubuntu.txt

# Create properties file for downstream jobs
# artifacts/magnet_link.txt is already available from previous build step

cat ubuntu_mirror_id.txt mirror_ubuntu.txt artifacts/magnet_link.txt > properties_file.txt
echo "BUILD_MIRROR_URL = ${BUILD_MIRROR_URL}" >> properties_file.txt
