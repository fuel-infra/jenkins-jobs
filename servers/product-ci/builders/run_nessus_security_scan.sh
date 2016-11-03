#!/bin/bash

set -ex

#MAGNET_LINK=$(sed s/MAGNET_LINK=// magnet_link.txt)

NESSUS_IMAGE_NAME=${NESSUS_IMAGE_NAME:=nessus}

rm -rf logs/*

virsh vol-delete "${NESSUS_IMAGE_NAME}.qcow2" --pool default || true
virsh vol-clone "${NESSUS_IMAGE_NAME}_orig.qcow2" "${NESSUS_IMAGE_NAME}.qcow2" --pool default

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

VERSION_STRING=$(basename "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: ${TEST_GROUP} on ${VERSION_STRING}"

rm -vf fuel-qa/logs/*

sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"
