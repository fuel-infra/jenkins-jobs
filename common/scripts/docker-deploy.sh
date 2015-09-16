#!/bin/bash

set -ex

docker pull "${REGISTRY_URL}/${IMAGE}"
