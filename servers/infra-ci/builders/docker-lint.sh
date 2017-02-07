#!/usr/bin/env bash
#
#   :mod:`docker-lint` -- Lint for docker-images
#   ==========================================
#
#   .. module:: docker-lint
#       :platform: Unix
#       :synopsis: This run linter on CI docker images
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Kirill Mashchenko <kmashchenko@mirantis.com>
#
#
#   This module runs linter on Dockerfiles for CI docker images
#
#   .. envvar::
#       :var  WORKSPACE: Location where build is started, defaults to ``.``
#       :type WORKSPACE: path
#       :var  IGNORE_CHECKS: List of hadolint rules to skip, divided by spaces
#       :type IGNORE_CHECKS: string
#
#
#   .. requirements::
#       * coreutils
#       * docker
#       * git
#       * grep
#
#
#   .. entrypoint:: main
#
#
#   .. seealso:: https://mirantis.jira.com/browse/PROD-9109
set -ex

docker_linter() {
    DOCKERFILE=${1}
    IGNORED_RULES=${2}
    IMAGE="lukasmartinelli/hadolint"
    IGNORE_ARG=""
    if [ "${IGNORED_RULES}" != "" ]; then
        for RULE in ${IGNORED_RULES}
        do
            IGNORE_ARG+=" --ignore ${RULE}"
        done
    fi
    docker pull ${IMAGE}
    # Using eval here needed to skip shellcheck errors, because we can't use
    # IGNORE_ARGS with quotes due to docker run arguments passing
    eval "docker run --rm -i ${IMAGE} hadolint - ${IGNORE_ARG} < ${DOCKERFILE}"
}

main() {
    pushd "${WORKSPACE}"
    DOCKERFILES=$(git -C "$WORKSPACE" diff --name-only HEAD~1 \
                | egrep "*/Dockerfile" \
                | sort|uniq)
    for DOCKERFILE in ${DOCKERFILES}
    do
        if [ ! -f "${DOCKERFILE}" ]; then
            continue
        fi
        docker_linter "${WORKSPACE}/${DOCKERFILE}" "${IGNORE_CHECKS}"
    done
    popd
}

WORKSPACE=${WORKSPACE:-"${PWD}"}
IGNORE_CHECKS=${IGNORE_CHECKS:-""}
main
