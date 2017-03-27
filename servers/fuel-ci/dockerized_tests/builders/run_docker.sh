#!/bin/bash
#
#   :mod:`run_docker` -- Docker container runner
#   =====================================================
#
#   .. module:: run_docker
#       :platform: Unix
#       :synopsis: Run Docker container with parameters
#   .. author:: Kirill Mashchenko <kmashchenko@mirantis.com>
#
#
#   .. envvar::
#       :var  IMAGE: Docker image name
#       :type IMAGE: str
#       :var  VOLUMES: Space-delimited key:value pairs of host directory
#                      and mount point inside Docker container
#       :type VOLUMES: str
#       :var  ENVVARS: Environment variables to use inside container
#       :type ENVVARS: str
#       :var  SCRIPT_ARGS: Optional argument to ``docker run`` command
#       :type SCRIPT_ARGS: str
#       :var  WORKSPACE: Location where build is started
#       :type WORKSPACE: path
#       :var  JOB_NAME: Jenkins job name
#       :type JOB_NAME: str
#       :var REGISTRY:
#       :type REGISTRY: str

set -ex

SCRIPT_PATH="${SCRIPT_PATH:-/opt/jenkins/runner.sh}"
SCRIPT_ARGS="${SCRIPT_ARGS:-}"
REGISTRY_PROTOCOL="${REGISTRY_PROTOCOL:-https}"
REGISTRY="${REGISTRY:-registry.fuel-infra.org}"
IMAGE="${IMAGE:-fuel-ci/base}"
VOLUMES="${VOLUMES:-}"
ENVVARS="${ENVVARS:-}"
WORKSPACE="${WORKSPACE:-${PWD}}"
JOB_NAME="${JOB_NAME:-debug_docker_script}"

restore_user_permissions() {
    # restore user permissions on workspace
    # shellcheck disable=SC2086
    docker run --rm -v ${WORKSPACE}:/workspace -t ubuntu /bin/bash -c "chown -R $(id -u):$(id -g) /workspace"
}

LATEST_IMAGE=$(curl -ksSL "${REGISTRY_PROTOCOL}://${REGISTRY}/v2/${IMAGE}/tags/list"|jq -r '.tags[]'|grep -v -e latest -e 2017|sort -n|tail -n1)

CMD_VOLUMES="-v ${WORKSPACE}:/opt/jenkins/${JOB_NAME}"
for volume in ${VOLUMES}; do
    CMD_VOLUMES+=" -v ${volume}"
done
bash -exc "docker pull ${REGISTRY}/${IMAGE}:${LATEST_IMAGE}"
restore_user_permissions
EXIT_CODE=0
# shellcheck disable=2086
docker run --rm ${CMD_VOLUMES} ${ENVVARS} -t ${REGISTRY}/${IMAGE}:${LATEST_IMAGE} /bin/bash -exc "${SCRIPT_PATH} ${SCRIPT_ARGS}" || EXIT_CODE=1
restore_user_permissions
exit ${EXIT_CODE}
