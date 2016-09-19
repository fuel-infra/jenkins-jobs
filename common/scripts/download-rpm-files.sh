#!/bin/bash
#
#   :mod: `download-rpm-files.sh` -- Download plugin files
#   ============================================
#
#   .. module:: download-rpm-files.sh
#       :platform: Unix
#       :synopsis: Script used to download plugin files
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Alexey Zvyagintsev <azvyagintsev@mirantis.com>
#
#   This script is used to download RPM or RPM's files directly from HTTP server
#
#   .. envvar::
#       :string RPM_PACKAGES_URLS - list of direct URL's to files
#               separator symbol: whitespace
#       :string PLUGIN_FILE - filename (usually XXXX.rpm)
#       :string RPM_REPO_URL - URL to reposiroty
#
#   .. depends::
#      plugin-deploy-test.sh
#      :string PLUGINS - where .rpm files should be downloaded
#

set -o errexit
set -o pipefail
set -o xtrace

PLUGINS=${PLUGINS:-plugins_data}
mkdir -p "${PLUGINS}"

if [[ -n "${RPM_PACKAGES_URLS}" ]]; then
    echo -e "INFO: need to download ${RPM_PACKAGES_URLS}\n into ${PLUGINS}"
    echo "WARNING: PLUGIN_FILE_PATH variable will not be updated!"
    pushd "${PLUGINS}"
        for  pkg_u in ${RPM_PACKAGES_URLS} ; do
            curl -O "${pkg_u}"
        done
    popd
else
    echo "INFO: RPM_PACKAGES_URLS variable not found"
    echo "INFO: Attempt to collect rpm ${PLUGIN_FILE} from published repo URL ${RPM_REPO_URL} "
    pushd "${PLUGINS}"
        curl -O "${RPM_REPO_URL}/Packages/${PLUGIN_FILE}"
    popd
    echo "INFO: Downloaded files:"
    ls -aln "${PLUGINS}"
fi
