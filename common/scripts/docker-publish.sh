#!/bin/bash

set -ex

for URL in ${REGISTRY_URLS}
do
  docker tag -f "internal-${NAME}:${TAG}" "${URL}/internal-${NAME}:${TAG}"
  docker push "${URL}/internal-${NAME}:${TAG}"
done
