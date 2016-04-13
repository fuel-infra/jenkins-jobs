#!/bin/bash

set -ex

source "${VENV_PATH}/bin/activate"
source "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

dos.py erase "${ENV_NAME}"
