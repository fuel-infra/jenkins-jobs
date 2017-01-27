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
#   .. author:: Dmitry Kaigarodtsev <dkaiharodsev@mirantis.com>
#
#
#   This script is used to publish a builded plugin to the mirror
#   by using 'trsync' tool
#
#
#   .. envvar::
#       :var  MIRROR_SERVER: destination host
#       :var  REMOTE_RSYNC_SHARE: rsync share name
#       :var  TRSYNC_DIR: folder with 'trsync'
#       :var  PLUGIN_FILE_PATH: path of builded plugin
#

set -ex
MIRROR_SERVER=${MIRROR_SERVER:-packages.fuel-infra.org}
REMOTE_RSYNC_SHARE=${REMOTE_RSYNC_SHARE:-mirror-sync/plugins}
TRSYNC_DIR=${TRSYNC_DIR:-trsync}
MIRROR_WEB_PATH=${MIRROR_WEB_PATH:-plugins}

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
        REPO_DIR="review/CR-${GERRIT_CHANGE_NUMBER}"
        ;;
    change-merged-event)
        REPO_DIR="${PLUGIN_NAME}/${PLUGIN_BRANCH}"
        ;;
esac

[ -d "${REPO_DIR}" ] && rm -rf "${REPO_DIR}"
mkdir -p "${REPO_DIR}"
cp "${PLUGIN_FILE_PATH}" "${REPO_DIR}"
createrepo "${REPO_DIR}"

trsync push "${REPO_DIR}" \
            -d "rsync://${MIRROR_SERVER}/${REMOTE_RSYNC_SHARE}" \
            -s "${REPO_DIR}" \
            --init-directory-structure

PLUGIN_URL="http://${MIRROR_SERVER}/${MIRROR_WEB_PATH}/${REPO_DIR}/${PLUGIN_FILE}"

cat << EOF >plugin-publish.envfile
PLUGIN_URL=${PLUGIN_URL}
PLUGIN_FILE=${PLUGIN_FILE}
PLUGIN_FILE_PATH=${WORKSPACE}/${PLUGIN_DIR}/${PLUGIN_FILE}
EOF
