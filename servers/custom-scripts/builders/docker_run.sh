#!/bin/bash

set -ex

COMMAND='true'
if [[ -f "/opt/${JOB_NAME}/requirements-deb.txt" ]] ; then
  COMMAND="$COMMAND ; apt-get install -y $(cat '/opt/${JOB_NAME}/requirements-deb.txt' | xargs)"
fi

if [[ -f "/opt/${JOB_NAME}/requirements-pip.txt" ]] ; then
  COMMAND="$COMMAND ; pip install -r /opt/${JOB_NAME}/requirements-pip.txt"
fi

docker run -v "${WORKSPACE}:/opt/${JOB_NAME}" \
           -v "${CONFIG_DIR}"/"${CONFIG_NAME}:${CONFIG_DIR}"/"${CONFIG_NAME}" \
              "${DOCKER_IMAGE}" /bin/bash -xc "$COMMAND ; /opt/${JOB_NAME}/${SCRIPT_PATH}"
