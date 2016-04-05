#!/bin/bash

set -x

# Default mounts
JOB_HOST_PATH="${WORKSPACE}/${JOB_NAME}"
JOB_DOCKER_PATH="/opt/jenkins/${JOB_NAME}"

# Path to runner script inside Docker image
SCRIPT_PATH="/opt/jenkins/runner.sh"

# Docker Registry to use
REGISTRY="registry.fuel-infra.org/fuel-ci/fuel-ci-tests"

# Container ID path
CONTAINER_ID="${WORKSPACE}/container.id"

CMDPARAM=;
for i in ${VOLUMES}; do
    CMDPARAM="${CMDPARAM} -v ${i}"
done

docker pull "${REGISTRY}:${DOCKER_IMAGE}"
docker run -v "${JOB_HOST_PATH}:${JOB_DOCKER_PATH}" ${CMDPARAM} \
           --cidfile="${CONTAINER_ID}" \
           ${ENVVARS} -t "${REGISTRY}:${DOCKER_IMAGE}" \
           /bin/bash -exc "${SCRIPT_PATH}"

# Stop container after job finishes, preserving exit code
exitcode=$?
docker stop "$(cat "${CONTAINER_ID}")"
exit $exitcode
