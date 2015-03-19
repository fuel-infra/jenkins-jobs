#!/bin/bash

set -ex

# Get the real build number from the lastSuccessfulBuild link

REAL_UPSTREAM_BUILD_NUMBER=$(curl "${UPSTREAM_JOB_URL}${UPSTREAM_BUILD_NUMBER}/buildNumber")
UPSTREAM_BUILD_URL="${UPSTREAM_JOB_URL}${REAL_UPSTREAM_BUILD_NUMBER}/"

# Create pretty description from UPSTREAM_JOB_URL and UPSTREAM_BUILD_NUMBER variables

echo "Description string: <a href=\"${UPSTREAM_BUILD_URL}\">ISO ${REAL_UPSTREAM_BUILD_NUMBER}</a>"

# Create artifact

echo "ISO_BUILD_URL=${UPSTREAM_BUILD_URL}" > iso_build_url.txt

# Fetch MAGNET_LINK

curl "${UPSTREAM_BUILD_URL}artifact/magnet_link.txt" -o magnet_link.txt
