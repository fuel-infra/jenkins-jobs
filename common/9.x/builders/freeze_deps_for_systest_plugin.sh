#!/bin/bash

set -ex
# TBD: This script will be extended with plugin-related data

# Variables:
# whole os plugin url example:
# PLUGIN_REPO_SUB_URL="extras/murano-plugin-repos/"
# PLUGIN_VERSION="release/1.0.0" or ""
# PLUGIN_MOS_VERSION="mos9.0"
# PLUGIN_PKG_DIST="centos7"
# http://mirror.fuel-infra.org/extras/murano-plugin-repos/centos/mos9.0-centos7/os
#
# For guess rpm filename
# PLUGIN_RPM_MASK="detach-murano"

# fixme: mirror.fuel-infra.org could point to brokem mirror
MIRROR_HOST="${MIRROR_HOST:-mirror.seed-cz1.fuel-infra.org}"

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

function store() {
    echo "$1=$2" >> snapshots.params
    echo "$1=\"$2\"" >> snapshots.sh
}


function guess_rpm_filename(){

   # Dirty hack, for determine rpm filename from repo, by mask
   # Should be rewrited to yumdownloared based soluthion
   local t_file;t_file=$(mktemp)
   local file_mask;file_mask=$1
   local snapshot_id;snapshot_id=$2

   wget  "${plugin_repo_long_url}/snapshots/${snapshot_id}/x86_64/Packages/" -O "${t_file}"
   store "PLUGIN_RPM_FILENAME_FROM_REPO" "$(grep "${file_mask}" "${t_file}" | sed -n 's/.*href="\([^"]*\).*/\1/p'  | sort -u | head -n 1)"
   rm -vf "${t_file}"
}

# Store snapshot for copy of rpm repo
# http://mirror.fuel-infra.org/extras/murano-plugin-repos/centos/mos9.0-centos7/os.target.txt >>
# http://mirror.fuel-infra.org/extras/murano-plugin-repos/centos/mos9.0-centos7/snapshots/os-2016-09-21-210927/
#                                                                                         ^^^^^^^^^^^^^^^^^^^^
plugin_repo_long_url="http://${MIRROR_HOST}/${PLUGIN_REPO_SUB_URL}/${PLUGIN_VERSION}/centos/${PLUGIN_MOS_VERSION}-${PLUGIN_PKG_DIST}/"

__plugin_latest_repo_snaphot_url="$(\
    curl "${plugin_repo_long_url}/os.target.txt" \
    | head -1)"
plugin_latest_repo_snaphot_id="${__plugin_latest_repo_snaphot_url##*/}"
store "PLUGIN_OS_REPO_ID" "${plugin_latest_repo_snaphot_id}"

guess_rpm_filename "${PLUGIN_RPM_MASK}" "${plugin_latest_repo_snaphot_id}"
