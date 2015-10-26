#!/bin/bash

set -ex

for URL in ${REGISTRY_URLS}
do
  docker tag -f "infra-${NAME}:${TAG}" "${URL}/infra-${NAME}:${TAG}"
  docker push "${URL}/infra-${NAME}:${TAG}"
done
