#!/bin/bash

set -ex

ISO_NAME=fuel-community-${ISO_ID}
TARBALL_NAME=fuel-community-${UPGRADE_ID}

seedclient.py -pvf "${ARTIFACTS_DIR}/${ISO_NAME}.iso" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

seedclient.py -pvf "${ARTIFACTS_DIR}/${ISO_NAME}.img" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

seedclient.py -pvf "${ARTIFACTS_DIR}/${TARBALL_NAME}.tar.lrz" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

echo "META: ${ISO_ID}: <a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.iso.torrent?from=jenkins>ISO</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.img.torrent?from=jenkins>IMG</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/${TARBALL_NAME}.tar.lrz.torrent?from=jenkins>UPGD</a>"
