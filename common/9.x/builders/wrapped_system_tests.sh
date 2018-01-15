#!/bin/bash

set -ex

# Set statistics job-group properties for swarm tests

FUEL_STATS_HOST="fuel-collect-systest.infra.mirantis.net"
ANALYTICS_IP="fuel-stats-systest.infra.mirantis.net"

export FUEL_STATS_HOST="${FUEL_STATS_HOST}"
export ANALYTICS_IP="${ANALYTICS_IP}"

rm -rf logs/*

# hack below for avoiding "Monitor path too big" issue
# "system_test.ubuntu." prefix is useless in current swarm runs
ENV_PREFIX="${ENV_PREFIX//system_test.ubuntu.}"
# VM name should be shorter than 59 chars
# ENV_NAME should be shorter than 47 chars ( 59-len(_slave_01)-len(.100) )
# ENV_PREFIX should be shorter than 43 chars (4 chars are reserved for ".$BUILD_ID")
ENV_PREFIX="${ENV_PREFIX:0:43}"
ENV_NAME="${ENV_PREFIX}.${BUILD_ID}"

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
