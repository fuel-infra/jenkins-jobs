#!/bin/bash

set -ex

# stable/4.1 -> 4_1
# master -> master
BRANCH_ID=$(echo "${BRANCH##*/}" | sed 's:\.:_:g')

if [ "${ISO_ID}" == "default" ]; then
  ISO_ID=${BRANCH_ID}
  ENV_POSTFIX="${BRANCH_ID}"
else
  ENV_POSTFIX="${ISO_ID}-${BRANCH_ID}"
fi

ISO_PATH="/home/jenkins/workspace/iso/fuel_${ISO_ID}.iso"

if [ ! -L "${ISO_PATH}" ]; then
  exit -1
fi

VERSION_STRING=$(readlink "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: ${NODE} - ${VERSION_STRING}<br>${ENV_PREFIXES}<br>${SHA}"

# Create copies of fuel-qa repo for each prefix

source "${VENV_PATH}/bin/activate"

mkdir -p "/home/jenkins/workspace/fuel-main/"

for ENV_PREFIX in ${ENV_PREFIXES}; do
    rm -rf "/home/jenkins/workspace/fuel-main/${ENV_PREFIX}-${ENV_POSTFIX}"
    cp -r fuel-main/ "/home/jenkins/workspace/fuel-main/${ENV_PREFIX}-${ENV_POSTFIX}"
    dos.py erase "${ENV_PREFIX}-${ENV_POSTFIX}" || echo "Nothing to erase"
done


