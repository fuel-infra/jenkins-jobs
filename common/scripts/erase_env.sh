#!/bin/bash

set -ex

source ${VENV_PATH}/bin/activate

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}
ENV_NAME=${ENV_NAME:0:68}

dos.py erase ${ENV_NAME}
