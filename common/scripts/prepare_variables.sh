#!/bin/bash

# BVT_JOB_URL - should be set in the project over {bvt_job_url} jjb variable

set -ex

LAST_SUCCESSFUL_BUILD=${LAST_SUCCESSFUL_BUILD:-lastSuccessfulBuild/artifact}
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

rm -f ./*.txt

# check and use latest values
if [ "${FUEL_QA_COMMIT}" = "latest-stable" ] ; then
    export $(curl -sSf "${BVT_JOB_URL}/${LAST_SUCCESSFUL_BUILD}/fuel_qa_commit.txt")
fi

if [ "${MAGNET_LINK}" = "latest-stable" ] ; then
    export $(curl -sSf "${BVT_JOB_URL}/${LAST_SUCCESSFUL_BUILD}/magnet_link.txt")
fi

if [ "${UBUNTU_MIRROR_ID}" = "latest-stable" ] ; then
    export $(curl -sSf "${BVT_JOB_URL}/${LAST_SUCCESSFUL_BUILD}/ubuntu_mirror_id.txt")
fi

# mirror customisation
if [ "${MIRROR_HOST}" != "none" ] ; then
    UBUNTU_MIRROR_URL="${MIRROR_HOST}/${UBUNTU_MIRROR_ID}/"
    MIRROR_UBUNTU_DATA="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"
    echo "${MIRROR_UBUNTU_DATA}" > mirror_ubuntu_data.txt
fi

echo "FUEL_QA_COMMIT=${FUEL_QA_COMMIT}" > fuel_qa_commit.txt
echo "MAGNET_LINK=${MAGNET_LINK}" > magnet_link.txt
echo "UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID}" > ubuntu_mirror_id.txt
