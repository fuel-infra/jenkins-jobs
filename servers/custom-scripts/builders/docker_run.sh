#!/bin/bash

set -ex

JOB_HOST_PATH="${WORKSPACE}/${JOB_NAME}"
JOB_DOCKER_PATH="/opt/${JOB_NAME}"

JENKINS_ID=`id -u`

COMMAND='true'
if [[ -f "${JOB_HOST_PATH}/requirements-deb.txt" ]] ; then
  COMMAND="${COMMAND} && apt-get update && apt-get install -y $(xargs < "${JOB_HOST_PATH}/requirements-deb.txt")"
fi

if [[ -f "${JOB_HOST_PATH}/requirements-pip.txt" ]] ; then
  COMMAND="${COMMAND} && pip install -r ${JOB_DOCKER_PATH}/requirements-pip.txt"
fi

docker run --rm -v "${JOB_HOST_PATH}:${JOB_DOCKER_PATH}" ${VOLUMES} \
           -t "${DOCKER_IMAGE}" /bin/bash -exc "${COMMAND} ; /opt/${SCRIPT_PATH} ${MODE}; chown -R ${JENKINS_ID} /opt"
