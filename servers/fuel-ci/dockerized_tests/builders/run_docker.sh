#!/bin/bash
#
#   :mod:`run_docker` -- Docker container runner
#   =====================================================
#
#   .. module:: run_docker
#       :platform: Unix
#       :synopsis: Run Docker container with parameters
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Anton Tcitlionok <atcitlionok@mirantis.com>
#
#
#   .. envvar::
#       :var  DOCKER_IMAGE: Docker image name
#       :type DOCKER_IMAGE: str
#       :var  VOLUMES: Space-delimited key:value pairs of host directory
#                      and mount point inside Docker container
#       :type VOLUMES: str
#       :var  ENVVARS: Environment variables to use inside container
#       :type ENVVARS: str
#       :var  MODE: Optional argument to ``docker run`` command
#       :type MODE: str
#       :var  WORKSPACE: Location where build is started
#       :type WORKSPACE: path
#       :var  JOB_NAME: Jenkins job name
#       :type JOB_NAME: str

# Container should be stopped only after job is finished,
# so exit code is processed manually.
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
for volume in ${VOLUMES}; do
    CMDPARAM="${CMDPARAM} -v ${volume}"
done

docker pull "${REGISTRY}:${DOCKER_IMAGE}"

# ENVVARS, VOLUMES and MODE variables should not be encased in
# double-quotes, otherwise single-quotes parameters will not be parsed
# shellcheck disable=SC2086
docker run -v "${JOB_HOST_PATH}:${JOB_DOCKER_PATH}" ${CMDPARAM} \
           --cidfile="${CONTAINER_ID}" \
           ${ENVVARS} -t "${REGISTRY}:${DOCKER_IMAGE}" \
           /bin/bash -exc "${SCRIPT_PATH} ${MODE}"

# Stop container after job finishes, preserving exit code
exitcode=$?
docker stop "$(cat "${CONTAINER_ID}")"
exit ${exitcode}
