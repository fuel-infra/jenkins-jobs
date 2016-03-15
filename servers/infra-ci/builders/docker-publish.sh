#!/bin/bash

set -ex

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
    docker tag -f "${IMAGE}" "${URL}/${IMAGE}"
    docker push "${URL}/${IMAGE}"
  done
done
