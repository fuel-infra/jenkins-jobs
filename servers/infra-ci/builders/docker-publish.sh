#!/bin/bash

set -ex

for URL in ${REGISTRY_URLS}
do
  docker tag -f "infra/${IMAGE_NAME}:${IMAGE_TAG}" "${URL}/infra/${IMAGE_NAME}:${IMAGE_TAG}"
  docker push "${URL}/infra/${IMAGE_NAME}:${IMAGE_TAG}"
done
