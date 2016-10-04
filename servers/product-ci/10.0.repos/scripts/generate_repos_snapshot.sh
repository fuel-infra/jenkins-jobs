#!/bin/bash

set -ex

# we just search for snapshots, no need to guess nearest
# MIRROR_HOST="mirror.fuel-infra.org"

# fixme: mirror.fuel-infra.org could point to brokem mirror
MIRROR_HOST="mirror.seed-cz1.fuel-infra.org"

MOS_UBUNTU_VERSION=${MOS_UBUNTU_VERSION:-master}
MOS_CENTOS_VERSION=${MOS_CENTOS_VERSION:-master}
if [[ "${MOS_CENTOS_VERSION}" = "master" ]]; then
    MOS_CENTOS_REPO_PREFIX="mos-master"
else
    MOS_CENTOS_REPO_PREFIX="mos${MOS_CENTOS_VERSION}"
fi

rm -rvf snapshots.params snapshots.sh

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

function store() {
    echo "$1=$2" >> snapshots.params
    echo "$1=\"$2\"" >> snapshots.sh
}

store "MOS_UBUNTU_VERSION" "${MOS_UBUNTU_VERSION}"
store "MOC_CENTOS_VERSION" "${MOS_CENTOS_VERSION}"


# Create and store ID of this snapshot file, which will be used as PK for snapshot set

# id for testrail to report test results
__snapshot_id_default="snapshot #${BUILD_NUMBER?}"
__snapshot_id="${CUSTOM_VERSION:-$__snapshot_id_default}"
store "CUSTOM_VERSION" "${__snapshot_id}"


# Store FUEL_QA_COMMIT

store "FUEL_QA_COMMIT" "$(git -C . rev-parse HEAD)"


# Store snapshot for copy of Ubuntu deb repo

# http://mirror.seed-cz1.fuel-infra.org/pkgs/ubuntu-2016-07-13-172538
#                                            ^^^^^^^^^^^^^^^^^^^^^^^^
__ubuntu_latest_repo_snaphot_url="$(\
    curl "http://${MIRROR_HOST}/pkgs/ubuntu-latest.htm" \
    | head -1)"
__ubuntu_latest_repo_snaphot_id="${__ubuntu_latest_repo_snaphot_url##*/}"
store "UBUNTU_MIRROR_ID" "${__ubuntu_latest_repo_snaphot_id}"



# Store snapshot for copy of Centos rpm repo

# http://mirror.fuel-infra.org/pkgs/snapshots/centos-7.2.1511-2016-05-31-083834/
#                                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
__centos_latest_repo_snaphot_url="$(\
    curl "http://${MIRROR_HOST}/pkgs/centos-latest.htm" \
    | head -1)"
__tmp="${__centos_latest_repo_snaphot_url%/}"
__centos_latest_repo_snaphot_id="${__tmp##*/}"
store "CENTOS_MIRROR_ID" "${__centos_latest_repo_snaphot_id}"



# Store snapshot for MOS deb repo

# 9.0-2016-06-23-164100
# ^^^^^^^^^^^^^^^^^^^^^
__mos_latest_deb_mirror_id="$(\
    curl "http://${MIRROR_HOST}/mos-repos/xenial/snapshots/${MOS_UBUNTU_VERSION}-latest.target.txt" \
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
        curl "http://${MIRROR_HOST}/mos-repos/centos/${MOS_CENTOS_REPO_PREFIX}-centos7/snapshots/${_dn}-latest.target.txt" \
        | head -1)"
    store "MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID" "${__dt_snapshot}"
done
