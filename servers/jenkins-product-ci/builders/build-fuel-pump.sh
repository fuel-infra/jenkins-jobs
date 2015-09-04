#!/bin/bash

set -ex

: ${WORKSPACE:=$(pwd -P)}
readonly \
  RSYNC_URL="rsync://osci-mirror-msk.msk.mirantis.net:/mirror-sync/appliance"
readonly IMAGE="fuel-pump.qcow2"

build_image() {
  local ubuntu_image="ubuntu-14.04.3-server-amd64.iso"

  [[ ! -f ${ubuntu_image} && ! -f ${HOME}/${ubuntu_image} ]] &&
    rsync -v "${RSYNC_URL}/${ubuntu_image}" "${HOME}"

  [[ ! -f ${ubuntu_image} ]] && cp -f "${HOME}/${ubuntu_image}" .

  bash -ex fuel-pump/build
  [[ -f build/${IMAGE} ]] || exit 2
}

upload_image() {
  rsync -v build/${IMAGE} "${RSYNC_URL}/images/${IMAGE}-$(date '+%Y%m%d-%s')"
}

main() {
  pushd "${WORKSPACE}"

  build_image
  upload_image

  popd
}

main "$@"
