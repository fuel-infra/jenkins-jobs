#!/bin/bash

set -ex

rm -rvf snapshots.params snapshots.sh snapshots.export.sh

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

function store() {
    echo "$1=$2" >> snapshots.params
    echo "$1=\"$2\"" >> snapshots.sh
    echo "export $1=\"$2\"" >> snapshots.export.sh
}


store "CUSTOM_VERSION" "snapshot #${BUILD_NUMBER?}"
store "MIRROR_HOST" "${MIRROR_HOST?}"
store "SNAPSHOT_TIMESTAMP" "$(date +%s)"
store "MAGNET_LINK" "${MAGNET_LINK?}"

# snapshot for copy of ubuntu deb repo
if [[ -n "${SRC_UBUNTU_MIRROR}" ]]; then
    __ubuntu_latest_repo_snaphot_id=$(curl -sSf "${MIRROR_HOST}/${SRC_UBUNTU_MIRROR}" | sed '1p;d')
    store "UBUNTU_MIRROR_ID" "${__ubuntu_latest_repo_snaphot_id}"
fi

# snapshot for copy of centos rpm repo
if [[ -n "${SRC_CENTOS_MIRROR}" ]]; then
    __centos_latest_repo_snaphot_id=$(curl -sSf "${MIRROR_HOST}/${SRC_CENTOS_MIRROR}" | sed '1p;d')
    store "CENTOS_MIRROR_ID" "${__centos_latest_repo_snaphot_id}"
fi

# snapshot for mos ubuntu deb repo
__mos_latest_deb_mirror_id="$(curl "${MIRROR_HOST}/${SRC_MOS_UBUNTU_MIRROR}" | head -1)"
store "MOS_UBUNTU_MIRROR_ID" "${__mos_latest_deb_mirror_id}"

# snapshots for all mos centos rpm repos
for _dn in  "os" "proposed" "updates" "holdback" "hotfix" "security"; do
    echo "Using auto-generated ${_dn} repo"
    __dt_snapshot="$(curl "${MIRROR_HOST}/${SRC_MOS_CENTOS_REPOS_PREFIX}/${_dn}-latest.target.txt" | head -1)"
    store "MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID" "${__dt_snapshot}"
done

if [[ -n "${SRC_CENTOS_SECURITY_PROPOSED}" ]]; then
    store "CENTOS_SECURITY_PROPOSED" "${SRC_CENTOS_SECURITY_PROPOSED}"
fi

