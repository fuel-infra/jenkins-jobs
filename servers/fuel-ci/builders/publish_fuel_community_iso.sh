#!/bin/bash

set -ex

ISO_NAME=fuel-community-${ISO_ID}
TARBALL_NAME=fuel-community-${UPGRADE_ID}

seedclient.py -pvf "${ARTIFACTS_DIR}/${ISO_NAME}.iso" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

# we don't have img artifact for >=6.1
if [ -f "${ARTIFACTS_DIR}/${ISO_NAME}.img" ]; then
  seedclient.py -pvf "${ARTIFACTS_DIR}/${ISO_NAME}.img" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333
fi

seedclient.py -pvf "${ARTIFACTS_DIR}/${TARBALL_NAME}.tar.lrz" --tracker-url=http://retracker.local:80/announce,http://seed-us1.fuel-infra.org:8080/announce,http://seed-cz1.fuel-infra.org:8080/announce --http-root=http://seed-cz1.fuel-infra.org/fuelweb-iso,http://seed-us1.fuel-infra.org/fuelweb-iso --seed-host=seed-us1.fuel-infra.org:17333,seed-cz1.fuel-infra.org:17333

if [ -f "${ARTIFACTS_DIR}/${ISO_NAME}.img" ]; then
  echo "META: ${ISO_ID}: <a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.iso.torrent?from=jenkins>ISO</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.img.torrent?from=jenkins>IMG</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/${TARBALL_NAME}.tar.lrz.torrent?from=jenkins>UPGD</a>"
  echo "DESCRIPTION=<a href=http://seed.fuel-infra.org/fuelweb-iso/fuel-community-$ISO_ID.iso.torrent?from=status>ISO</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/fuel-community-$ISO_ID.img.torrent?from=status>IMG</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/fuel-community-$UPGRADE_ID.tar.lrz.torrent?from=status>UPGD</a>" > description.txt
else
  # this is >=6.1 build
  echo "META: ${ISO_ID}: <a href=http://seed.fuel-infra.org/fuelweb-iso/${ISO_NAME}.iso.torrent?from=jenkins>ISO</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/${TARBALL_NAME}.tar.lrz.torrent?from=jenkins>UPGD</a>"
  echo "DESCRIPTION=<a href=http://seed.fuel-infra.org/fuelweb-iso/fuel-community-$ISO_ID.iso.torrent?from=status>ISO</a> <a href=http://seed.fuel-infra.org/fuelweb-iso/fuel-community-$UPGRADE_ID.tar.lrz.torrent?from=status>UPGD</a>" > description.txt
fi
