#!/bin/bash

set -ex

FUELCIDIR="fuel-ci-tests"

if [ -d "${FUELCIDIR}" ]
then
  IMAGES="$(echo "${FUELCIDIR}"/* | sed 's/\//:/g')"
else
  exit 1
fi

# Build images first
for IMAGE in ${IMAGES}
do
  IMAGE_NAME=$(echo "$IMAGE" | cut -f 1 -d:)
  IMAGE_TAG=$(echo "$IMAGE" | cut -f 2 -d :)

  echo "Cleaning a previous image first:"
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true

  # check if directory still exists
  if [ -f "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}/Dockerfile" ]
  then
    # build image
    echo "Rebuilding image:"
    cd "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}"
    docker build --no-cache -t "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" .
    # add image to publish list
    VIMAGES="${VIMAGES} ${IMAGE_NAME}:${IMAGE_TAG}"
    OUTPUT+="${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}<br>"
  fi
done

# Publish built images to Docker registries
for IMAGE in ${IMAGES}
do
  IMAGE_NAME=$(echo "$IMAGE" | cut -f 1 -d :)
  IMAGE_TAG=$(echo "$IMAGE" | cut -f 2 -d :)

  for URL in ${REGISTRY_URLS}
  do
    docker tag -f "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" "${URL}/${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}"
    docker push "${URL}/${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}"
  done
done
