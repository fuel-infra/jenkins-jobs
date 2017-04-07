#!/bin/bash -ex

#
#   :mod: `nessus_upload_results.sh` -- this script uploade result of security scan
#   =========================================================================
#
#   .. module:: nessus_upload_results.sh
#       :platform: Unix
#       :synopsys: this script uploade result of security scan
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var UPLOAD_HOST: host used for upload reports, for example ``!docs.fuel-infra.org``
#       :var UPLOAD_USER: username used for upload, for example ``!docs``
#       :var UPLOAD_PATH: path to reports directory (on a target node)
#
#   .. requirements::
#       * valid configuration YAML file: nessus_upload_results.sh
#
#   .. seealso::
#
#   .. warnings::

UPLOAD_USER="${UPLOAD_USER}"
UPLOAD_HOST="${UPLOAD_HOST}"
UPLOAD_PATH="${UPLOAD_PATH}"
TARGET_DIRECTORY="${WORKSPACE}/reports"
DATE=$(date +%F-%H)
TMPDIR=$(mktemp -d)

if rsync -l -e 'ssh' --protocol=29 "$UPLOAD_USER@$UPLOAD_HOST:$UPLOAD_PATH/${RELEASE_VERSION}"; then
    echo "${RELEASE_VERSION} directory already exists"
else
    echo "${RELEASE_VERSION} directory will be created"
    rsync -av -e 'ssh' --protocol=29 "${TMPDIR}" "$UPLOAD_USER@$UPLOAD_HOST:${UPLOAD_PATH}/${RELEASE_VERSION}"
fi
if rsync -l -e 'ssh' --protocol=29 "$UPLOAD_USER@$UPLOAD_HOST:${UPLOAD_PATH}/${RELEASE_VERSION}/${DATE}"; then
    echo "${RELEASE_VERSION}/${DATE} directory already exists"
else
    echo "${RELEASE_VERSION}/${DATE} directory will be created"
    rsync -av -e 'ssh' --protocol=29 "${TMPDIR}" "$UPLOAD_USER@$UPLOAD_HOST:${UPLOAD_PATH}/${RELEASE_VERSION}/${DATE}"
fi
rsyc -avP -e 'ssh' --protocol=29 "${TARGET_DIRECTORY}/*.html" "$UPLOAD_USER@$UPLOAD_HOST:${UPLOAD_PATH}/${RELEASE_VERSION}/${DATE}/"
rm -rf "${TMPDIR}"
rm -rf "${TARGET_DIRECTORY}"
