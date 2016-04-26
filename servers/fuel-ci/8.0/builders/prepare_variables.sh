#!/bin/bash

set -ex

rm -f *.txt

if [ "${MIRROR_HOST}" != "none" ] ; then
    UBUNTU_MIRROR_URL="${MIRROR_HOST}/${UBUNTU_MIRROR_ID}/"
    MIRROR_UBUNTU_DATA="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse"
    echo "${MIRROR_UBUNTU_DATA}" > mirror_ubuntu_data.txt
fi

echo "FUEL_QA_COMMIT=${FUEL_QA_COMMIT}" > fuel_qa_commit.txt
echo "MAGNET_LINK=${MAGNET_LINK}" > magnet_link.txt
echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt

