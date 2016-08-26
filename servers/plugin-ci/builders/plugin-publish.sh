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
PLUGIN_SERVER=${PLUGIN_SERVER:-packages.fuel-infra.org}
REMOTE_PLUGIN_DIR=${REMOTE_PLUGIN_DIR:-/var/www/mirror/plugins}
TRSYNC_DIR=${TRSYNC_DIR:-trsync}

# trsync install
VENV_PATH=$TRSYNC_DIR/.venv
virtualenv "$VENV_PATH"

source "$VENV_PATH/bin/activate"
pip install -r "$TRSYNC_DIR/requirements.txt"
pushd "${TRSYNC_DIR}" &>/dev/null
    python setup.py build
    python setup.py install
popd &>/dev/null

case "${GERRIT_EVENT_TYPE}" in
    patchset-created)
        REPO_DIR="review/CR-${PATCHSET_NUMBER}"
        ;;
    change-merged-event)
        REPO_DIR="${PLUGIN_NAME}/${PLUGIN_BRANCH}"
        ;;
esac

mkdir -p "${REPO_DIR}"
# export from properties file
export ${PLUGIN_FILE}
cp "${PLUGIN_FILE}" "${REPO_DIR}"
createrepo "${REPO_DIR}"

trsync push "${REPO_DIR}" \
            -d "${PLUGIN_SERVER}/${REPO_DIR}" \
            -s "${REPO_DIR}" \
            --init-directory-structure 
