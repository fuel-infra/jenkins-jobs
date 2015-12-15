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

delete_old_images() {
  local include_files="$(mktemp)"

  rsync --list-only "${RSYNC_URL}/images/" | \
    grep -oP ".*\K${IMAGE}-\d{8}-\d+\$" | \
    sort | \
    head -n -31 > "${include_files}"

  [[ ! -f "${include_files}" || ! -s "${include_files}" ]] && return 0

  rsync -rv --delete --include-from="${include_files}" --exclude='*' . \
    "${RSYNC_URL}/images/"

  rm -f "${include_files}"
}

main() {
  pushd "${WORKSPACE}"

  build_image
  upload_image
  delete_old_images

  popd
}

main "$@"
