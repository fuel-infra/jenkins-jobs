#!/bin/bash

set -ex

# get image tag first
DATE=$(date +"%Y-%m-%d-%H-%M-%S")
LATEST_TAG=${LATEST_TAG:-'false'}
DATE_TAG=${DATE_TAG:-'true'}

# if ${IMAGE} parameter is not set - use copied artifacts
if [ -z "${IMAGE}" ]
then
  source publish_env.sh
else
  IMAGES="${IMAGE}"
fi

# iterate through all the images
for IMAGE in ${IMAGES}
do
  for URL in ${REGISTRY_URLS}
  do
    docker tag "${IMAGE}" "${URL}/${IMAGE}"
    docker push "${URL}/${IMAGE}"
    # upload additional date tagged image
    if [[ "${DATE_TAG}" == 'true' ]]; then
      docker tag "${IMAGE}" "${URL}/${IMAGE}-${DATE}"
      docker push "${URL}/${IMAGE}-${DATE}"
      docker rmi "${URL}/${IMAGE}-${DATE}"
    fi
    if [[ "${LATEST_TAG}" == 'true' ]]; then
        IMAGE_LATEST=$(echo "${IMAGE}" | awk -F: '$NF="latest"' OFS=':')
        docker tag "${IMAGE}" "${URL}/${IMAGE_LATEST}"
        docker push "${URL}/${IMAGE_LATEST}"
        docker rmi "${URL}/${IMAGE_LATEST}"
    fi
    docker rmi "${URL}/${IMAGE}"
  done
done
