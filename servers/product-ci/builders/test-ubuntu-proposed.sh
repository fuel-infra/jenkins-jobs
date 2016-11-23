#!/bin/bash

set -ex

UBUNTU_DIST=${UBUNTU_DIST:-trusty}

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

# Create artifacts

# For current development release, take the magnet link from the last successfull ISO job
# For released versions, magnet link will be automatically injected from the data/X.X-iso file

echo MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse" > ubuntu_mirror.txt
echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt

# Create properties file for downstream jobs

cat magnet_link.txt ubuntu_mirror.txt ubuntu_mirror_id.txt > properties_file.txt
