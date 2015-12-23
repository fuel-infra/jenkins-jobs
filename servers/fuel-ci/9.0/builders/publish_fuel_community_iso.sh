#!/bin/bash

set -ex

ISO_NAME=fuel-community-${ISO_ID}

seedclient.py -pvf "${ARTIFACTS_DIR}/${ISO_NAME}.iso" \
  --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce \
  --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso \
  --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

echo "META: ${ISO_ID}: <a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.iso.torrent?from=jenkins>ISO</a>"
echo "DESCRIPTION=<a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.iso.torrent?from=status>ISO</a>" > description.txt
