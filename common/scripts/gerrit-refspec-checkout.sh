#!/bin/bash
#
#   :mod: `gerrit-refspec-checkout.sh` -- Checkout to refspec
#   ============================================
#
#   .. module:: gerrit-refspec-checkout.sh
#       :platform: Unix
#       :synopsis: Script used to checkout gerrit repo using gerrit refspec
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Alexey Zvyagintsev <azvyagintsev@mirantis.com>
#
#   This script is used to checkout gerrit repository using gerrit respec
#   Usefully, in case multiply scm modules are used in jenkins job
#
#   .. envvar::
#       :# All variables, passed from GERRIT_* zuul-event
#       :string GERRIT_REFSPEC: for example 'refs/changes/05/25805/18'
#       :string GERRIT_USER:
#       :string GERRIT_HOST:
#       :string GERRIT_PORT:
#       :string GERRIT_PROJECT: for example 'openstack/fuel-main'
#
#   .. warining::
#       Script work only if project cloned into BASEDIR with project basename
#       PROJECT_NAME.For example:
#        GERRIT_PROJECT=openstack/fuel-main
#        So project should be cloned into repo with name 'fuel-main'
#

set -o errexit
set -o pipefail
set -o xtrace

if [[ -n "${GERRIT_REFSPEC}" ]]; then
    gerrit_repo_url="ssh://${GERRIT_USER}@${GERRIT_HOST}:${GERRIT_PORT}/${GERRIT_PROJECT}"
    echo "INFO: Guess git repo checkout for project ${GERRIT_PROJECT}"
    project_dir=${GERRIT_PROJECT##*/}
    echo "INFO: Looking for project:${GERRIT_PROJECT} at dir ${project_dir}"
    if [[ ! -d "${project_dir}" ]]; then
        echo "WARNING: Project directory ${project_dir} not exist!"
        exit 0
    fi
    pushd "${project_dir}"
        echo "INFO: Switching to changeset ${GERRIT_REFSPEC}"
        git fetch "${gerrit_repo_url}" "${GERRIT_REFSPEC}"
        git checkout FETCH_HEAD
        git log -1 --pretty="%h"
    popd
else
    echo "INFO: GERRIT_REFSPEC variable not found"
fi
