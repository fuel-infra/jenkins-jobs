#!/bin/bash

set -ex

# we just search for snapshots, no need to guess nearest
# MIRROR_HOST="mirror.fuel-infra.org"

# fixme: mirror.fuel-infra.org could point to brokem mirror
MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

rm -rvf snapshots.params snapshots.sh

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

function store() {
    echo "$1=$2" >> snapshots.params
    echo "$1=\"$2\"" >> snapshots.sh
}



# Create and store ID of this snapshot file, which will be used as PK for snapshot set

# id for testrail to report test results
__snapshot_id_default="snapshot #${BUILD_NUMBER?}"
__snapshot_id="${CUSTOM_VERSION:-$__snapshot_id_default}"
store "CUSTOM_VERSION" "${__snapshot_id}"
# unix timestamp of snapshot
__snapshot_timestamp="$(date +%s)"
store "SNAPSHOT_TIMESTAMP" "${__snapshot_timestamp}"


# Create and store MAGNET_LINK

store "MAGNET_LINK" "${MAGNET_LINK?}"



# Store FUEL_QA_COMMIT

store "FUEL_QA_COMMIT" "$(git -C . rev-parse HEAD)"


# Store snapshot for copy of Ubuntu deb repo

# http://mirror.seed-cz1.fuel-infra.org/pkgs/snapshots/ubuntu-2016-07-13-172538
#                                                      ^^^^^^^^^^^^^^^^^^^^^^^^
__ubuntu_latest_repo_snaphot_id=$(curl -sSf "${MIRROR_HOST}/pkgs/snapshots/ubuntu-latest.target.txt" | sed '1p;d')
store "UBUNTU_MIRROR_ID" "${__ubuntu_latest_repo_snaphot_id}"



# Store snapshot for copy of Centos rpm repo

# http://mirror.fuel-infra.org/pkgs/snapshots/centos-7.2.1511-2016-05-31-083834/
#                                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
__centos_latest_repo_snaphot_id=$(curl -sSf "${MIRROR_HOST}/pkgs/snapshots/centos-7.3.1611-latest.target.txt" | sed '1p;d')
store "CENTOS_MIRROR_ID" "${__centos_latest_repo_snaphot_id}"



# Store snapshot for MOS deb repo

# 9.0-2016-06-23-164100
# ^^^^^^^^^^^^^^^^^^^^^
__mos_latest_deb_mirror_id="$(\
    curl "http://${MIRROR_HOST}/mos-repos/ubuntu/snapshots/9.0-latest.target.txt" \
    | head -1)"
store "MOS_UBUNTU_MIRROR_ID" "${__mos_latest_deb_mirror_id}"



# Store snapshots for full set of MOS rpm repos

# <distribution_name>-2016-07-14-082020
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
for _dn in  "os"        \
            "proposed"  \
            "updates"   \
            "holdback"  \
            "hotfix"    \
            "security"  ; do
    __dt_snapshot="$(\
        curl "http://${MIRROR_HOST}/mos-repos/centos/mos9.0-centos7/snapshots/${_dn}-latest.target.txt" \
        | head -1)"
    store "MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID" "${__dt_snapshot}"
done

