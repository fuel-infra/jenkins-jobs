#!/bin/bash

set -ex

## here comes latest ISO management
if [[ "${MAGNET_LINK}" == 'latest' ]]; then
  # check LATEST_MAGNET_LINK
  if [[ "${LATEST_MAGNET_LINK}" =~ ^http ]]; then
    # for web links on latest artefact
    export $(curl -sSf "${LATEST_MAGNET_LINK}")
  elif [[ "${LATEST_MAGNET_LINK}" =~ ^magnet ]]; then
    # for !include-raw: links
    MAGNET_LINK="${LATEST_MAGNET_LINK}"
  else
    echo "Cannot define latest ISO"
    exit 1
  fi
fi

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

# save it as inject variables
echo "ISO_PATH=${ISO_PATH}" > iso_path.txt

if [ ! -L "${ISO_PATH}" ]; then
  echo "ISO not found"
  exit -1
fi

VERSION_STRING=$(readlink "${ISO_PATH}" | cut -d '-' -f 2-3)
echo "Description string: ${NODE} - ${VERSION_STRING}<br>${ENV_NAME}<br>${SHA}"
