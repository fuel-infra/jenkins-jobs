#!/bin/bash

set -ex

echo "Cleaning a previous image first:"
docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true

echo "Clone repository with images:"
DESTINATION=$(mktemp -d)
git clone "${REPOSITORY}" "${DESTINATION}"

echo "Building a new image from the URL:"
cd "${DESTINATION}/${IMAGE_NAME}/${IMAGE_TAG}"
docker build -t "infra/${IMAGE_NAME}:${IMAGE_TAG}" .

echo "Cleanup temporary files"
rm -rf "${DESTINATION}"
