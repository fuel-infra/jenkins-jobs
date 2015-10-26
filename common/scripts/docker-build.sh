#!/bin/bash

set -ex

echo "Cleaning a previous image first:"
docker rmi "infra-${NAME}:${TAG}" 2>/dev/null || /bin/true

echo "Building a new image from the URL:"
docker build -t "infra-${NAME}:${TAG}" "${URL}"
