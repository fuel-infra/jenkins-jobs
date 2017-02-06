#!/bin/bash
#
#   :mod:`docker-build` -- Build docker-images script
#   ==========================================
#
#   .. module:: docker-build
#       :platform: Unix
#       :synopsis: This builds CI docker images
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Kirill Mashchenko <kmashchenko@mirantis.com>
#
#
#   This module builds and verifies CI docker images
#   It contains:
#       * docker build image function
#       * docker remove image function
#       * docker verify image function
#       * define image name, prefix and tag based on CONFIG file
#
#
#   .. envvar::
#       :var  BUILD_ID: Id of Jenkins build under which this
#                       script is running, defaults to ``0``
#       :type BUILD_ID: int
#       :var  WORKSPACE: Location where build is started, defaults to ``.``
#       :type WORKSPACE: path
#       :var ACTION: Defines action which will run. Possible values are
#                    ``verify-fuel-ci`` and ``build``, defaults to ``build``
#       :type ACTION: string
#       :var REBUILD: If true sets docker build --no-cache mode
#       :type REBUILD: bool
#       :var FORCE_PREFIX: Forces of using docker image namespace
#       :type FORCE_PREFIX: string
#       :var FILTER: Regexp for filtering of Dockerfile folders
#       :type FILTER: string
#
#   .. requirements::
#
#       * coreutils
#       * docker
#       * gawk
#       * git
#       * grep
#
#
#   .. class:: sample.envfile
#       :var  OUT: useless output variable
#       :type OUT: path
#
#
#   .. entrypoint:: main
#
#
#   .. affects::
#       :file publish_env.sh: list of urls for built images
#       :stdout: list of built images with tags
#
#
#   .. seealso:: https://mirantis.jira.com/browse/PROD-1052
#   .. warnings:: if BUILD_ID isn't defined, uses tag 'latest' for 'flat' images

set -ex

docker_build_image() {
    DOCKERFILE_PATH=${1}
    IMAGE_NAME=${2}
    IMAGE_TAG=${3}
    DOCKER_CLI_OPTS=${4}
    pushd .
    cd "${DOCKERFILE_PATH}"
    docker build "${DOCKER_CLI_OPTS}" -t "${IMAGE_NAME}:${IMAGE_TAG}" .
    popd
}

docker_rm_image() {
    IMAGE_NAME=${1}
    IMAGE_TAG=${2}
    echo "[ STATUS ] Cleaning a previous image first:"
    docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true
}

verify_fuel_ci() {
    IMAGE_NAME=${1}
    IMAGE_TAG=${2}
    CONTAINER_ID="${WORKSPACE}/container.id"
    SCRIPT_PATH="/opt/jenkins/runner.sh"
    # run default tests
    echo "[ STATUS ] Fuel CI image verification started."
    docker run --cidfile="${CONTAINER_ID}" -t "${IMAGE_NAME}:${IMAGE_TAG}" \
            /bin/bash -exc ${SCRIPT_PATH} verify_image
    exitcode=$?
    docker stop "$(cat "${CONTAINER_ID}")"
    echo "[ STATUS ] Fuel-ci verification exit code was ${exitcode}"
}

main() {
    if [ "${REBUILD}" == "true" ]; then
        BUILD_OPTS="--no-cache"
        echo "[ INFO ] Rebuild is called, setting --no-cache mode"
    fi
    pushd .
    cd "${WORKSPACE}"
    IMAGES=$(git -C "${WORKSPACE}" diff  --name-only HEAD~1 \
             | egrep "${FILTER}" \
             | awk -F"/" '{print $1":"$2}' \
             |sort|uniq)
    OUTPUT='[urls]'
    for IMAGE in ${IMAGES}
    do
        TYPE="tagged" # tagged, flat
        PREFIX="infra"
        FIRST_NAME=$(echo "${IMAGE}" |awk -F":" '{print $1}')
        SECOND_NAME=$(echo "${IMAGE}" |awk -F":" '{print $2}')
        DOCKERFILE_LOC="${WORKSPACE}/${FIRST_NAME}/${SECOND_NAME}"
        if [ ! -f "${DOCKERFILE_LOC}/Dockerfile" ]; then
            continue
        fi

        if [ -f "${FIRST_NAME}/CONFIG" ]; then
            source "${FIRST_NAME}/CONFIG"
        fi
        NAMESPACE=${FORCE_PREFIX:-$PREFIX}
        if [ "${TYPE}" == "flat" ]; then
            IMAGE_NAME=${SECOND_NAME}
            IMAGE_TAG=${BUILD_ID:-latest}
            echo "[ STATUS ] Building a new flat image from the URL:"
            image_name="${NAMESPACE}/${IMAGE_NAME}"
            docker_build_image "${DOCKERFILE_LOC}" "${image_name}" "${IMAGE_TAG}" "${BUILD_OPTS}"
        else
            IMAGE_NAME=${FIRST_NAME}
            IMAGE_TAG=${SECOND_NAME}
            echo "[ STATUS ] Building a new tagged image from the URL:"
            image_name="${NAMESPACE}/${IMAGE_NAME}"
            docker_build_image "${DOCKERFILE_LOC}" "${image_name}" "${IMAGE_TAG}" "${BUILD_OPTS}"
        fi
        if [ "${ACTION}" == "verify-fuel-ci" ]; then
            verify_fuel_ci "${image_name}" "${IMAGE_TAG}"
        fi
        VIMAGES="${VIMAGES} ${image_name}:${IMAGE_TAG}"
        OUTPUT+="${image_name}:${IMAGE_TAG}<br>"
    done
    # remove trailing, leading spaces
    VIMAGES=$(echo -e "${VIMAGES}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    echo "IMAGES='${VIMAGES}'" > "${WORKSPACE}/publish_env.sh"
    popd
    echo "${OUTPUT}"
}

ACTION=${ACTION:-build}
WORKSPACE=${WORKSPACE:-"${PWD}"}
REBUILD=${REBUILD:-"false"}
BUILD_ID=${BUILD_ID:-}
FORCE_PREFIX=${FORCE_PREFIX:-}
FILTER=${FILTER:="."}
main