#!/bin/bash

set -ex

PLUGINS_URLS_FILE='plugins_urls'
echo "${PLUGINS}" > "${WORKSPACE}/${PLUGINS_URLS_FILE}"
wget --no-verbose --input-file="${WORKSPACE}/${PLUGINS_URLS_FILE}" --directory-prefix="${PLUGINS_DIR}"
