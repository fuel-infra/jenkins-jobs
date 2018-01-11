#!/bin/bash

set -ex

# Set statistics job-group properties for swarm tests

FUEL_STATS_HOST="fuel-collect-systest.infra.mirantis.net"
ANALYTICS_IP="fuel-stats-systest.infra.mirantis.net"

export FUEL_STATS_HOST="${FUEL_STATS_HOST}"
export ANALYTICS_IP="${ANALYTICS_IP}"

rm -rf logs/*

ENV_PREFIX="${ENV_PREFIX:0:56}" # libvirt cant handle VM name >60 length
ENV_NAME="${ENV_PREFIX?}.${ENV_SUFFIX?}"
ENV_NAME="${ENV_NAME:0:60}"

# done for destroy step
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

# save name for destruction step
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK?}" -v --force-set-symlink -o "${WORKSPACE?}")

echo "Description string: ${TEST_GROUP?} on ${CUSTOM_VERSION?}"

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT:-false}

env

sh  -x "utils/jenkins/system_tests.sh"  \
    -t test                             \
    -w "${WORKSPACE}"                   \
    -e "${ENV_NAME}"                    \
    -o                                  \
    --group="${TEST_GROUP}"             \
    -i "${ISO_PATH}"

# remove env if not set verbosely to keep it

if [[ "${KEEP_ENV:-false}" = false ]] ; then
    source "${VENV_PATH}/bin/activate"
    dos.py erase "${ENV_NAME}"
fi
