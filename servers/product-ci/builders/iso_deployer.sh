#!/bin/bash

set -ex

if [[ -z "${MAGNET_LINK}" ]]; then
  echo "No magnet link provided!"
  exit 1
fi

seedclient-wrapper -dvm "${MAGNET_LINK}"
