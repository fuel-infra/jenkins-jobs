#!/bin/bash

set -ex

if [ ! -L "${ISO_PATH}" ]; then
  echo "ISO not found"
  exit -1
fi

VERSION_STRING=$(readlink "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: ${NODE} - ${VERSION_STRING}<br>${ENV_NAMES}<br>${SHA}"

mkdir -p "${SYSTEST_ROOT}"

rm -rf "${SYSTEST_ROOT}"
cp -r fuel-qa/ "${SYSTEST_ROOT}"

source "${VENV_PATH}/bin/activate"
for ENV_NAME in ${ENV_NAMES}; do
    dos.py erase "${ENV_NAME}" || echo "Can not erase $ENV_NAME"
done
deactivate
