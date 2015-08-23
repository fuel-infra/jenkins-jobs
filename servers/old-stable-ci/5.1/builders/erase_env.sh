#!/bin/bash
set -ex

VENV_PATH=${VENV_PATH:-/home/jenkins/venv-nailgun-tests}

source "${VENV_PATH}/bin/activate"

ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}
dos.py erase "${ENV_NAME}"

echo FINISHED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" >> ci_status_params.txt
