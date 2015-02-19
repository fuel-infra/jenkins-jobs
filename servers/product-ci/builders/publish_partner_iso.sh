#!/bin/bash

set -ex

MAGNET_LINK=$(echo "${MAGNET_LINK}" | sed -e 's/&/\\&/g')

ssh -o StrictHostKeyChecking=no ${DST_HOST} seedclient.py -v -d -o ${DST_DIR} -m "${MAGNET_LINK}"
