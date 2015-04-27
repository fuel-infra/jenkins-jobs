#!/bin/bash

set -ex

HOSTS=$(host "${DST_HOST}" | grep 'has address' | awk '{ print $NF }')

FILE=$(seedclient.py -v -d -o "${WORKSPACE}" -m "${MAGNET_LINK}")
for HOST in $HOSTS; do
    scp -o StrictHostKeyChecking=no "${FILE}" "${DST_USERNAME}\@${HOST}:${DST_DIR}"
done
