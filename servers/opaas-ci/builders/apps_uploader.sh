#!/bin/bash

#   .. module:: apps_uploader.sh
#       :platform: Ubuntu. Linux
#       :synopsis: Zip murano-app's from git, and upload them to OS for test.
#   .. author:: Alexey Zvyagintsev <azvyagintsev@mirantis.com>
#
#   .. Require: apt-get install python-dev python-virtualenv python-pip
#               zip build-essential libssl-dev libffi-dev

set -ex
# FIXME remove this line after https://bugs.launchpad.net/mos/+bug/1594853
export MURANO_REPO_URL='http://bug-1594853.com/'

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE="${WORKSPACE:-${DIR}}"
#
VENV_PATH_DEFAULT="${WORKSPACE}/../murano_test_venv/"
VENV_PATH="${VENV_PATH:-${VENV_PATH_DEFAULT}}"
export ARTIFACTS_DIR="${WORKSPACE}/artifacts/"
#
# Remove old VENV?
VENV_CLEAN="${VENV_CLEAN:-false}"
#
# Prefix require for deleting OLD app from app-list
# example for app "io.murano.apps.docker.kubernetes.KubernetesPod"
APP_PREFIX="${APP_PREFIX:-io.test_upload.}"
#
# whole path to package will be: GIT_ROOT/APPS_ROOT/PACKAGES_LIST/package
APPS_ROOT="${APPS_ROOT:-/murano-apps/}"
APPS_DIR="${WORKSPACE}/${APPS_ROOT}/"
#
# test, to be run
RUN_TEST="${RUN_TEST:-none}"
#
# Upload app's to OpenStack?
UPLOAD_TO_OS="${UPLOAD_TO_OS:-false}"
#
# Define commit list, if needed
COMMIT_LIST="${COMMIT_LIST:-none}"
#
GIT_REPO="${GIT_REPO:-openstack/ci-cd-pipeline-app-murano}"
# List of murano app catalogs, to be archived and uploaded into OS
#PACKAGES_LIST="Puppet SystemConfig OpenLDAP Gerrit Jenkins"

function prepare_venv() {
    echo 'LOG: Creating python venv for murano-client'
    mkdir -p "${VENV_PATH}"
    virtualenv --system-site-packages  "${VENV_PATH}"
    source "${VENV_PATH}/bin/activate"
    #FIXME install from requirments.txt ?
    pip install pytz debtcollector
    pip install git+https://github.com/openstack/python-muranoclient.git python-heatclient --upgrade
}

function build_packages() {
   for pkg_long in ${PACKAGES_LIST}; do
       local pkg=$(basename "${pkg_long}")
       art_name="${ARTIFACTS_DIR}/${APP_PREFIX}${pkg}.zip"
       pushd "${APPS_DIR}/${pkg_long}/package"
       zip -r "${art_name}" ./*
       popd
   done
}

# Body

mkdir -p "${ARTIFACTS_DIR}"
echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > "${ARTIFACTS_DIR}/ci_status_params.txt"

# remove arts from previous run
echo  'LOG: printenv:'
printenv | grep -v "OS_USERNAME\|OS_PASSWORD"
find "${ARTIFACTS_DIR}" -type f -exec rm -f {} \;

# Checking gerrit commits for GIT_REPO
if [[ ("${COMMIT_LIST}" != "none") ]] ; then
  for commit in ${COMMIT_LIST} ; do
    git fetch https://review.openstack.org/"${GIT_REPO}" "${commit}"
    git cherry-pick FETCH_HEAD
  done
fi

if [[ ! -z "${PACKAGES_LIST}" ]] ; then
    build_packages
fi

if [[ "${UPLOAD_TO_OS}" == true ]] ; then
    if [[ ("${VENV_CLEAN}" == true) || (! -f "${VENV_PATH}/bin/activate") ]]; then
        prepare_venv
    fi
    source "${VENV_PATH}/bin/activate"
    echo "LOG: murano version: $(murano --version)"
    # Some app's have external dependency's
    # - so we should have ability to clean-up them also
    if [[ "${APPS_CLEAN}" == true ]]; then
        echo  'LOG: Removing ALL apps from tenant...'
        pkg_ids=($(murano package-list --owned |grep -v 'ID\|--' |awk '{print $2}'))
        for id in "${pkg_ids[@]}"; do
          murano package-delete "${id}" || true
        done
    fi
    # to have ability upload one package independently we need to remove it
    echo "LOG: removing old packages..."
    for pkg_long in ${PACKAGES_LIST}; do
        pkg=$(basename "${pkg_long}")
        art_name="${ARTIFACTS_DIR}/${APP_PREFIX}${pkg}.zip"
        pkg_id=$(murano package-list --owned |awk "/$pkg/ {print \$2}")
        if [[ -n "${pkg_id}" ]] ; then
        # FIXME remove 'true', after --owned flag will be fixed
        # https://bugs.launchpad.net/mos/+bug/1593279
        murano package-delete "${pkg_id}" || true
        fi
    done
    # via client and then upload it without updating its dependencies
    echo "LOG: importing new packages..."
    for pkg_long in ${PACKAGES_LIST}; do
        pkg=$(basename "${pkg_long}")
        art_name="${ARTIFACTS_DIR}/${APP_PREFIX}${pkg}.zip"
        murano package-import "${art_name}" --exists-action s
    done
    echo "LOG: importing done, final package list:"
    murano package-list --owned
fi

if [[ "${RUN_TEST}" != none ]] ; then
    echo "LOG: trying run openstack deployment..."
    if [[ ("${VENV_CLEAN}" == true) || (! -f "${VENV_PATH}/bin/activate") ]]; then
        prepare_venv
    fi
    # TBD Here should be test_run call
    source "${VENV_PATH}/bin/activate"
    ./"${RUN_TEST}"

fi
echo FINISHED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" >> "${ARTIFACTS_DIR}/ci_status_params.txt"
