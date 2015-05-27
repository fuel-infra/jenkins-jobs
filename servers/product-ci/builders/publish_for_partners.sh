#!/bin/bash

set -ex

HOSTS=$(host "${DST_HOST}" | grep 'has address' | awk '{ print $NF }')

FILE=$(seedclient.py -v -d --force-set-symlink -o "${WORKSPACE}" -m "${MAGNET_LINK}")
for HOST in $HOSTS; do
    rsync -Lv "${FILE}" "${DST_USERNAME}@${HOST}:${DST_DIR}/"
done
