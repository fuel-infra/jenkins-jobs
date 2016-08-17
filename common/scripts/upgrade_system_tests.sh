#!/bin/bash

#   :mod: `upgrade_system_tests` -- upgrade tests build starter
#   ================================================================
#
#   .. module: upgrade_system_tests
#       :platform: Unix
#       :synopsis: set environment and execute custom upgrade system
#                  tests according to configuration yaml file and
#                  Jenkins user defined (filled in) parameters
#   .. versionadded: MOS-9.0
#   .. versionchanged: MOS-9.0
#   .. author: Artur Mihura (amihura@mirantis.com)
#
#
#
#   At the moment tests are executed for Fuel 7.0 to 8.0, 8.0 to 9.x,
#   upgrade and backup-restore 9.x to 9.x but in bright future it will
#   be possible to test any old build  versus any new one (Jira epic
#   to grasp the whole view: #PROD-4465). Script sets build environment,
#   executes ${base_repo}  test groups, then (keeping the same environment)
#   runs ${upgrade_repo} ones. All of them originate from Fuel QA testing
#   framework.
#
#   .. envvar::
#       :var WORKSPACE: build starting location (defaults to '.')
#       :var NODES_COUNT: sufficient (min) number of slaves to run tests
#       :var ENV_NAME: contains build number (BUILD_NUMBER) and build ID
#          (BUILD_ID) related  info (deployed)
#       :var VENV_PATH: build specific virtual environment path (deployed)
#       :var MAKE_SNAPSHOT: failed steps  snapshots are created (default
#          behavior when value='false'. When 'true', made for each step)
#       :var BASE_REPO_BRANCH: old (base) product release branch
#       :var UPGRADE_REPO_BRANCH: new (upgrade) product release branch
#       :var BASE_FUEL_PROPOSED_REPO_URL: proposed repository with updates
#          for old (base) release packages
#       :var UPGRADE_FUEL_PROPOSED_REPO_URL: proposed repository with
#          updates for new (upgrade) release packages
#       :var BASE_FUEL_QA_GERRIT_COMMIT: patches committed for old (base)
#          release in fuel-qa repository, absent in stable product branch
#          (defined in yaml, default to 'none')
#       :var UPGRADE_FUEL_QA_GERRIT_COMMIT: patches committed for new
#          (upgrade) release in fuel-qa repository, absent in stable
#          product branch (defined in yaml, default to 'none')
#       :var ISO_MAGNET_LINK: magnet link to specific product release ISO
#          image (to avoid huge files uploading). It comes pre-deployed,
#          results in BASE_ISO_MAGNET_LINK (related to old release) and
#          UPGRADE_ISO_MAGNET_LINK (related to new release)
#
#   .. requrements::
#       * valid magnet link to base and upgrade Fuel ISO images
#         (data/<release>-iso)
#       * valid link to base and upgrade proposed repositories
#         with packages

set -ex

# colors definition
green='\e[1;32m'
red='\e[1;31m'
NC='\e[0m' # no color

# print error messages in red ($1 - message)
function error_message(){
    echo
    echo -e "${red}>>> ${NC}$1"
}

# print info messages in green ($1 - message)
function info_message(){
    echo
    echo -e "${green}>>> ${NC}$1"
}


# global variables to export (files/logs are usually stored separately
# for each test; keep them all in one place for convenience)
export LOGS_DIR="${WORKSPACE}/logs"
export FILES_DIR="${WORKSPACE}/additional_files"
export NODES_COUNT=10
export MAKE_SNAPSHOT

# proposed repositories with updates for specific release packages
export BASE_FUEL_PROPOSED_REPO_URL
export UPGRADE_FUEL_PROPOSED_REPO_URL

# to support Maintenance updates certain proposed repos should be set
# ENABLE_PROPOSED flag should be 'true' by default (details in #1584686)
ENABLE_PROPOSED="${ENABLE_PROPOSED:-true}"

function set_MU_proposed_repos(){
    # hard-coding URLs (along with long lines) is evil, so split them
    # MIRROR_HOST is injected (comes from guess-mirror macros)
    MIRROR_HOST=${MIRROR_HOST}
    REPO="mos-proposed,deb"

    if [[ "${ENABLE_PROPOSED}" != true ]]; then
        unset UPDATE_FUEL_MIRROR
        unset EXTRA_DEB_REPOS
        return
    fi

    if [[ "${UPGRADE_FUEL_FROM}" = "9.1" || "${UPGRADE_FUEL_TO}" = "9.1" ]]; then
      curl -s https://product-ci.infra.mirantis.net/view/9.x/job/9.x.snapshot/lastSuccessfulBuild/artifact/snapshots.sh > "${WORKSPACE}/vars.sh"
      source "${WORKSPACE}/vars.sh"
    fi

    FUEL_PROPOSED_7="mos-repos/centos/mos7.0-centos6-fuel/snapshots/proposed-latest/x86_64/"
    FUEL_PROPOSED_8="mos-repos/centos/mos8.0-centos7-fuel/snapshots/proposed-latest/x86_64/"
    FUEL_PROPOSED_9="mos-repos/centos/mos9.0-centos7/snapshots/${MOS_CENTOS_PROPOSED_MIRROR_ID}/x86_64"

    MOS_EXTRA_DEB_7="mos-repos/ubuntu/snapshots/7.0-latest mos7.0-proposed main restricted"
    MOS_EXTRA_DEB_8="mos-repos/ubuntu/snapshots/8.0-latest mos8.0-proposed main restricted"
    MOS_EXTRA_DEB_9="mos-repos/ubuntu/snapshots/${MOS_UBUNTU_MIRROR_ID} mos9.0-proposed main restricted"

    # form MU repo URLs both for base and upgrade releases
    # there's no need to apply MOS updates beforehand, 'cause
    # according to Fuel QA routine, they are always applied
    case "${1}" in
        base)
            if [[ "${UPGRADE_FUEL_FROM}" = "7.0" ]]; then
              UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_7}"
              EXTRA_DEB_REPOS="${REPO} http://${MIRROR_HOST}/${MOS_EXTRA_DEB_7}"
            elif [[ "${UPGRADE_FUEL_FROM}" = "8.0" ]]; then
              UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_8}"
              EXTRA_DEB_REPOS="${REPO} http://${MIRROR_HOST}/${MOS_EXTRA_DEB_8}"
            elif [[ "${UPGRADE_FUEL_FROM}" = "9.1" ]]; then
              UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_9}"
              EXTRA_DEB_REPOS="${REPO} http://${MIRROR_HOST}/${MOS_EXTRA_DEB_9}"
            fi
            ;;
        upgrade)
            if [[ "${UPGRADE_FUEL_TO}" = "7.0" ]]; then
              UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_7}"
              EXTRA_DEB_REPOS="${REPO} http://${MIRROR_HOST}/${MOS_EXTRA_DEB_7}"
            elif [[ "${UPGRADE_FUEL_TO}" = "8.0" ]]; then
              UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_8}"
              EXTRA_DEB_REPOS="${REPO} http://${MIRROR_HOST}/${MOS_EXTRA_DEB_8}"
            elif [[ "${UPGRADE_FUEL_TO}" = "9.1" ]]; then
              UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_9}"
              EXTRA_DEB_REPOS="${REPO} http://${MIRROR_HOST}/${MOS_EXTRA_DEB_9}"
            fi
    esac
    export UPDATE_FUEL_MIRROR
    export EXTRA_DEB_REPOS
    export UPDATE_MASTER="true"
}

# to avoid huge images uploading magnet links are used
# (ISO_MAGNET_LINK variables come pre-deployed)
BASE_ISO_PATH=$(seedclient-wrapper -d -m "${BASE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
UPGRADE_ISO_PATH=$(seedclient-wrapper -d -m "${UPGRADE_ISO_MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
export ENV_NAME="${ENV_NAME:0:68}"
export VENV_PATH

# check which test group is to run (specified in yaml)
function check_test_group(){
    # there are specific sets of test groups for particular release
    # thus test_group variables should not be empty
    # check test_group is not empty and fail (exit) otherwise
    case "${1}" in
        base)
            test_group="${BASE_TEST_GROUP}"
            ;;
        upgrade)
            test_group="${UPGRADE_TEST_GROUP}"
    esac

    info_message "Checking which ${1} test group to run..."
    if [[ -z "${test_group}" ]] ; then
        error_message "${test_group} is empty! Please specify it Jenkins job."
        exit 1
    else
        export TEST_GROUP="${test_group}"
    fi
}

# check if 'logs' directory exists, create it otherwise
function check_logs_dir(){
    if [[ ! -e "${LOGS_DIR}" ]]; then
        mkdir -p "${LOGS_DIR}"
        info_message "Logs will be stored in ${LOGS_DIR}"
    fi
}

function remove_old_logs(){
    info_message "Trashing old logs in ${LOGS_DIR} to avoid confusion..."
    rm -f "${LOGS_DIR}"/*
}

# both base and upgrade release repositores are checked out
BASE_REPO_DIR="${REPO_NAME}-base"
UPGRADE_REPO_DIR="${REPO_NAME}-upgrade"

# check logs and additional files directories exist, create otherwise
function check_directories(){
    pushd "${repo_dir}"
        check_logs_dir
    popd
}

# create test environment for specific release and start system tests
function system_tests_wrapper(){
    case "${1}" in
        base)
            iso_path="${BASE_ISO_PATH}"
            repo_dir="${BASE_REPO_DIR}"
            repo_branch="${BASE_REPO_BRANCH}"
            unset keep_build_env
            FUEL_PROPOSED_REPO_URL="${BASE_FUEL_PROPOSED_REPO_URL}"
            ;;
        upgrade)
            iso_path="${UPGRADE_ISO_PATH}"
            repo_dir="${UPGRADE_REPO_DIR}"
            repo_branch="${UPGRADE_REPO_BRANCH}"
            keep_build_env="-k"
            FUEL_PROPOSED_REPO_URL="${UPGRADE_FUEL_PROPOSED_REPO_URL}"
    esac

    export FUEL_PROPOSED_REPO_URL

    info_message "Setting up maintenance updates repos for ${repo_branch}..."
    set_MU_proposed_repos "${1}"

    info_message "Creating test environment for fuel-qa: ${repo_branch}..."
    pushd "${repo_dir}"
        check_test_group "${1}"
    popd

    # fuel-qa scripts have different ${WORKSPACE} than fuel-ci ones
    # thus force -w to point to ${workspace} instead of ${WORKSPACE}
    workspace="${WORKSPACE}/${repo_dir}"

    # keep_build_env is used to  keep build environemnt for further
    # reuse (otherwise it is wiped/created for new product release)
    # utils is system tests starter (of fuel-qa origin)
    utils="utils/jenkins/system_tests.sh"

    info_message "Executing ${TEST_GROUP} tests for ${repo_branch}..."

    pushd "${repo_dir}"
        sh -x "${utils}" \
            "${keep_build_env}" \
            -t test \
            -w "${workspace}" \
            -j "${JOB_NAME}" \
            -o --group="${TEST_GROUP}" \
            -i "${iso_path}"

        if [[ $? -ne 0 ]] ; then
            error_message "System tests from ${repo_branch} failed."
            error_message "Please check logs in ${LOGS_DIR} for details."
            exit 1
        fi

        info_message "System tests from ${repo_branch} passed."
    popd
}

# set up test environment and execute particular groups of system tests
check_directories
remove_old_logs
system_tests_wrapper base
system_tests_wrapper upgrade

info_message "Upgrade systems tests finished successfully."
