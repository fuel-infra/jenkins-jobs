#!/bin/bash
#
#   :mod: `publish-plugin.sh` -- Publish newly builded plugins
#   ===============================================================
#
#   .. module:: publish-plugin.sh
#       :platform: Unix
#       :synopsis: Script used to publish newly builded plugins
#   .. vesionadded:: MOS-10.0
#   .. vesionchanged:: MOS-10.0
#   .. author:: Alexey Golubev <agolubev@mirantis.com>
#
#
#   This script is used to publish a builded plugin to a specified directory
#   on the server
#
#
#   .. envvar::
#       :var  PLUGIN_DIR: plugins directory
#       :var  PLUGIN_SERVER: publisher server
#       :var  PLUGIN_BRANCH: plugin branch
#       :var  PLUGIN_USER: user on publisher server
#

set -ex

PLUGIN_FILE=$(basename "$(ls "${PLUGIN_DIR}"/*.rpm)")
REPO_DIR="${PLUGIN_DIR}/${PLUGIN_FILE}/rpm/"

case "${GERRIT_EVENT_TYPE}" in
    patchset-created)
        TARGET_DIR="/plugins/review/CR-${PATCHSET_NUMBER}"
        ;;
    change-merged-event)
        TARGET_DIR="/plugins/${PLUGIN_NAME}/${PLUGIN_BRANCH}"
        ;;
esac

mkdir "${REPO_DIR}"
createrepo "${REPO_DIR}"

# Variables should be expanded on client side
# shellcheck disable=SC2029
ssh "${PLUGIN_USER}@${PLUGIN_SERVER}" mkdir -p "${TARGET_DIR}" && \
scp -r "${REPO_DIR}" "${PLUGIN_USER}@${PLUGIN_SERVER}:${TARGET_DIR}"
