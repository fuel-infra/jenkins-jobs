#!/bin/bash

set -ex

FILE=$(seedclient.py -v -d -o ${WORKSPACE} -m "${MAGNET_LINK}")
scp -o StrictHostKeyChecking=no ${FILE} ${DST_HOST}:${DST_DIR}
