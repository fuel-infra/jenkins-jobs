#!/bin/bash
#
#   :mod:`build-late-artifacts` -- A Wrapper for building late artifacts
#   ====================================================================
#
#   .. module:: build-late-artifacts
#       :platform: Ubuntu 14.04
#       :synopsis: building late artifacts
#   .. vesionadded:: MOS-8.0 patching
#   .. vesionchanged:: MOS-9.0 patching
#   .. author:: Ivan Remizov <iremizov@mirantis.com>
#
#
#   .. envvar::
#       :var  FUELMAIN_COMMIT: commit for fuel-main
#       :type FUELMAIN_COMMIT: refspec:str
#       :var  fuelmain_gerrit_commit: refspecs for commits in ``fuel-main`` gerrit
#       :type fuelmain_gerrit_commit: arr[refspec:str]
#       :var  EXTRA_RPM_REPOS: list of rpm repos to use at build step
#       :type EXTRA_RPM_REPOS: arr[str]
#       :var  make_args: list of additional parameters to make command
#       :type make_args: arr[str]
#       :var  JOB_NAME: Name of Jenkins Job
#       :type JOB_NAME: str
#       :var  WORKSPACE: Location where build is started, defaults to ``.``
#       :type WORKSPACE: path
#
#   .. requirements::
#
#       * sudo
#       * vivid kernel
#       * docker
#
#   .. class:: sample.envfile
#       FIXME: Add description for artifact
#
#
#   .. entrypoint:: main
#
#
#   .. affects::
#       :file buildresult.params: dumped env variables
#                                 similar to zuul pipelines
#

set -ex

export BUILD_DIR="$(readlink -e "${WORKSPACE}/../tmp/${JOB_NAME}/build")"
export LOCAL_MIRROR="$(readlink -e "${WORKSPACE}/../tmp/${JOB_NAME}/local_mirror")"
export ARTS_DIR="${WORKSPACE}/artifacts"
export DEPS_DIR="${BUILD_DIR}/deps"
export DESTINATION_DIR="$(readlink -e "${WORKSPACE}/../tmp/${JOB_NAME}/late-artifacts")"

main () {
    #   .. function:: main
    #
    #       Creates late artifacts
    #
    #       :output ${ARTS_DIR}/buildresult.params: file with
    #                       results which could be used by publisher job
    #       :type   ${ARTS_DIR}/buildresult.params: buildresult.params
    #
    #       :stdin: not used
    #       :stdout: debug info
    #       :stderr: not used
    #
    echo "STEP 1/4. Clean before start"
    # =================================

    for _d in "${ARTS_DIR}" "${DEPS_DIR}" "${DESTINATION_DIR}" ; do
        rm -rf "${_d}"
        mkdir -p "${_d}"
    done


    echo "STEP 2/4. Apply crunches"
    # =============================

    git checkout "${FUELMAIN_COMMIT}"
    for commit in ${fuelmain_gerrit_commit} ; do
        git fetch https://review.openstack.org/openstack/fuel-main "${commit}" && git cherry-pick FETCH_HEAD
    done


    echo "STEP 3/4. Make packages-late target"
    # ========================================

    make deep_clean

    # make_args is list of additional args
    # shellcheck disable=SC2086
    make packages-late ${make_args}

    echo "STEP 4/4. Gather results"
    # ========================================

    # copy pkgs
    find "${BUILD_DIR}/packages/rpm/RPMS/" -type f -name '*.rpm' -exec cp -v {} "${DESTINATION_DIR}" \;
    ls "${DESTINATION_DIR}"

    touch "${ARTS_DIR}/buildresult.params"

    cat > "${ARTS_DIR}/buildresult.params" <<EOF
BUILD_HOST=$(hostname)
PKG_PATH=${DESTINATION_DIR}
GERRIT_CHANGE_STATUS=MERGED
REQUEST_NUM=
LP_BUG=
IS_SECURITY=false
EXTRAREPO=${EXTRA_RPM_REPOS}
REPO_TYPE=rpm
DIST=centos7

# Added for publisher
ORIGIN=Mirantis
IS_UPDATES=true
REPO_REQUEST_PATH_PREFIX=review/
REPO_BASE_PATH=/home/jenkins/pubrepos
RPM_OS_REPO_PATH=mos-repos/centos/mos8.0-centos7-fuel/os
RPM_PROPOSED_REPO_PATH=mos-repos/centos/mos8.0-centos7-fuel/proposed
RPM_UPDATES_REPO_PATH=mos-repos/centos/mos8.0-centos7-fuel/updates
RPM_SECURITY_REPO_PATH=mos-repos/centos/mos8.0-centos7-fuel/security
RPM_HOLDBACK_REPO_PATH=mos-repos/centos/mos8.0-centos7-fuel/holdback
REMOTE_REPO_HOST=perestroika-repo-tst.infra.mirantis.net
EOF
}

main