#!/bin/bash

set -ex

source "${VENV_PATH}/bin/activate"
ENVS=$(dos.py list --timestamp | grep nessus | cut -d ' ' -f1)
if [ -n "${ENVS}" ] ; then
    for ENV in ${ENVS} ; do dos.py erase "${ENV}" ; done
fi

