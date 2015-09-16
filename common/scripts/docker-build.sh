#!/bin/bash

set -ex

echo "Cleaning a previous image first:"
docker rmi "internal-${NAME}:${TAG}" 2>/dev/null || /bin/true

echo "Building a new image from the URL:"
docker build -t "internal-${NAME}:${TAG}" "${URL}"
