#!/bin/bash

#   :mod: `upgrade_systest_step` -- upgrade tests executor
#   ================================================================
#
#   .. module: upgrade_system_tests
#       :platform: Unix
#       :synopsis: set environment and execute upgrade system test step
#                  tests according to configuration yaml file and
#                  Jenkins user defined (filled in) parameters
#   .. versionadded: MOS-9.1
#   .. versionchanged: MOS-9.1
#   .. author: Vladimir Khlyunev (vkhlyunev@mirantis.com)
#
#   This script is developed for running upgrade test step based on environment
#   variables received from Jenkins. This script should be used several times
#   for building correct pipeline between fuel's versions and fuel-qa branches
#   .. envvar::
#       :var WORKSPACE: build starting location (defaults to '.')
#       :var NODES_COUNT: sufficient (min) number of slaves to run tests
#       :var ENV_NAME: contains build number (BUILD_NUMBER) and build ID
#          (BUILD_ID) related  info (deployed)
#       :var VENV_PATH: build specific virtual environment path (deployed)
#       :var CURRENT_FUEL_VERSION: version of Fuel used in current step
#       :var ENABLE_PROPOSED: bool, flag for applying proposed repos to the env
#       :var MIRROR_HOST: hostname of server where all our repos are located
#       :var FUEL_PROPOSED_7: path to Fuel 7.0 proposed repo on MIRROR_HOST
#       :var MOS_EXTRA_DEB_7: path to MOS 7.0 proposed repo on MIRROR_HOST
#       :var FUEL_PROPOSED_8: path to Fuel 8.0 proposed repo on MIRROR_HOST
#       :var MOS_EXTRA_DEB_8: path to MOS 8.0 proposed repo on MIRROR_HOST
#       :var MOS_CENTOS_OS_MIRROR_ID: Directory which contains snapshot
#       :var MOS_CENTOS_PROPOSED_MIRROR_ID: Directory which contains snapshot
#       :var MOS_CENTOS_UPDATES_MIRROR_ID: Directory which contains snapshot
#       :var MOS_CENTOS_SECURITY_MIRROR_ID: Directory which contains snapshot
#       :var MOS_CENTOS_HOLDBACK_MIRROR_ID: Directory which contains snapshot
#       :var MOS_CENTOS_HOTFIX_MIRROR_ID: Directory which contains snapshot
#       :var ENABLE_MOS_UBUNTU_PROPOSED: Use new proposed repo for cloud deployment
#       :var ENABLE_MOS_UBUNTU_UPDATES: Use new updates repo for cloud deployment
#       :var ENABLE_MOS_UBUNTU_SECURITY: Use new security repo for cloud deployment
#       :var ENABLE_MOS_UBUNTU_HOLDBACK: Use new holdback repo for cloud deployment
#       :var ENABLE_MOS_CENTOS_OS: Use new os repo for Fuel deployment
#       :var ENABLE_MOS_CENTOS_PROPOSED: Use new proposed repo for Fuel deployment
#       :var ENABLE_MOS_CENTOS_UPDATES: Use new updates repo for Fuel deployment
#       :var ENABLE_MOS_CENTOS_SECURITY: Use new security repo for Fuel deployment
#       :var ENABLE_MOS_CENTOS_HOLDBACK: Use new holdback repo for Fuel deployment
#       :var ISO_PATH: magnet link to Fuel ISO under testing
#       :var OCTANE_REPO_LOCATION: URL to latest octane repo location (if
#          differs from proposed repos)
#       :var REPO_DIR: Current fuel-qa repository directory
#       :var VENV_PATH: Path to virtual environment with all required packages
#       :var TEST_GROUP: fuel-qa's testgroup for execution
#
#   .. requrements::
#       * valid magnet link to the Fuel iso
#       * valid link to base and upgrade proposed repositories
#         with packages

set -ex


function join() {
    local __sep="${1}"
    local __head="${2}"
    local __tail="${3}"

    if [[ -n "${__head}" ]]; then
        echo "${__head}${__sep}${__tail}"
    else
        echo "${__tail}"
    fi
}

function to_uppercase() {
    echo "$1" | awk '{print toupper($0)}'
}

function set_MU_proposed_repos(){
    ENABLE_PROPOSED="${ENABLE_PROPOSED:-true}"
    if [[ "${ENABLE_PROPOSED}" != true ]]; then
        unset UPDATE_FUEL_MIRROR
        unset EXTRA_DEB_REPOS
        return
    fi

    export UPDATE_FUEL_MIRROR
    export EXTRA_DEB_REPOS

    if [[ "${1}" = "7.0" ]]; then
      UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_7}"
      EXTRA_DEB_REPOS="mos-proposed,deb http://${MIRROR_HOST}/${MOS_EXTRA_DEB_7}"
    elif [[ "${1}" = "8.0" ]]; then
      UPDATE_FUEL_MIRROR="http://${MIRROR_HOST}/${FUEL_PROPOSED_8}"
      EXTRA_DEB_REPOS="mos-proposed,deb http://${MIRROR_HOST}/${MOS_EXTRA_DEB_8}"
    elif [[ "${1}" = "9.0" || "${1}" = "9.1" || "${1}" = "9.x" ]]; then
      # copypasted from "wrapped_system_tests.sh" for removing issues with applying of 9.x
      __space=' '
      __pipe='|'

      # Adding Fuel rpm repos to
      # - UPDATE_FUEL_MIRROR - will be used for fuel in cluster
      for _dn in  "os"        \
            "proposed"        \
            "updates"         \
            "holdback"        \
            "hotfix"          \
            "security"        ; do
        # a pointer to variable name which holds value of enable flag for this dist name
        __enable_ptr="ENABLE_MOS_CENTOS_$(to_uppercase "${_dn}")"
        if [[ "${!__enable_ptr}" = true ]] ; then
            # a pointer to variable name which holds repo id
            __repo_id_ptr="MOS_CENTOS_$(to_uppercase "${_dn}")_MIRROR_ID"
            __repo_url="http://${MIRROR_HOST}/mos-repos/centos/mos9.0-centos7/snapshots/${!__repo_id_ptr}/x86_64"
            __repo_name="mos-${_dn},${__repo_url}"
            UPDATE_FUEL_MIRROR="$(join "${__space}" "${UPDATE_FUEL_MIRROR}" "${__repo_url}" )"
        fi
      done
      # Adding MOS deb repos to
      # - EXTRA_DEB_REPOS - will be used for nodes in cluster
      for _dn in  "proposed"    \
                    "updates"   \
                    "holdback"  \
                    "hotfix"    \
                    "security"  ; do
            # a pointer to variable name which holds value of enable flag for this dist name
            __enable_ptr="ENABLE_MOS_UBUNTU_$(to_uppercase "${_dn}")"
            # a pointer to variable name which holds repo id
            __repo_id_ptr="MOS_UBUNTU_MIRROR_ID"
            __repo_url="http://${MIRROR_HOST}/mos-repos/ubuntu/snapshots/${!__repo_id_ptr}"
            if [[ "${!__enable_ptr}" = true ]] ; then
                __repo_name="mos-${_dn},deb ${__repo_url} mos9.0-${_dn} main restricted"
                EXTRA_DEB_REPOS="$(join "${__pipe}" "${EXTRA_DEB_REPOS}" "${__repo_name}")"
            fi
      done
    fi
}

ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
export ENV_NAME="${ENV_NAME:0:68}"
export NODES_COUNT="${NODES_COUNT:-10}"

export LOGS_DIR="${WORKSPACE}/logs"
export UPDATE_MASTER=true

export ISO_PATH=$(seedclient-wrapper -d -m "${ISO_MAGNET}" -v --force-set-symlink -o "${WORKSPACE}")

echo "Executing ${TEST_GROUP} tests for ${REPO_DIR}..."

pushd "${REPO_DIR}"

    set_MU_proposed_repos "${CURRENT_FUEL_VERSION}"

    source "${VENV_PATH}/bin/activate"

    pip install --upgrade -r "fuelweb_test/requirements.txt"

    sh -x "utils/jenkins/system_tests.sh" -k -w "$(pwd)" \
        -j "${JOB_NAME}" -o --group="${TEST_GROUP}"
popd

echo "Upgrade systems tests step finished successfully."
