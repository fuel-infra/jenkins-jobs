#!/bin/bash

set -ex

# if ${IMAGE} parameter is not set - use copied artifacts
if [ -z "${IMAGE}" ]
then
  source to_publish.txt
else
  PREFIX=$(echo "$IMAGE" | cut -f 1 -d /)
  IMAGES=$(echo "$IMAGE" | cut -f 2 -d /)
fi

# iterate through all the images
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
