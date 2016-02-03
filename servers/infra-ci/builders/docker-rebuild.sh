#!/bin/bash

set -ex

OUTPUT="[urls]"

PREFIX=$(echo "$IMAGE" | cut -f 1 -d '/')
IMAGE=$(echo "$IMAGE" | cut -f 2 -d '/')

IMAGE_NAME=$(echo "$IMAGE" | cut -f 1 -d :)
IMAGE_TAG=$(echo "$IMAGE" | cut -f 2 -d :)

echo "Cleaning a previous image first:"
docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true

# check if directory still exists
if [ -f "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}/Dockerfile" ]
then
  # build image
  echo "Building a new image from the URL:"
  cd "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}"
  docker build --no-cache -t "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" .
  # add published URL
  OUTPUT+="${PREFIX}/${IMAGE}<br>"
else
  exit 1
fi

echo "${OUTPUT}"
