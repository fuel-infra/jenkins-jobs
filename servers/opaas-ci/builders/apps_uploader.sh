#!/bin/bash

#   .. module:: apps_uploader.sh
#       :platform: Ubuntu. Linux
#       :synopsis: Zip murano-app's from git, and upload them to OS for test.
#   .. author:: Alexey Zvyagintsev <azvyagintsev@mirantis.com>
#
#   .. Require: apt-get install python-dev python-virtualenv python-pip
#               python-tox zip build-essential libssl-dev libffi-dev

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE="${WORKSPACE:-${DIR}}"
DEFAULT_MURANO_REPO_URL="${MURANO_REPO_URL:-http://storage.apps.openstack.org/}"
#
VENV_PATH_DEFAULT="${WORKSPACE}/../murano_test_venv/"
VENV_PATH="${VENV_PATH:-${VENV_PATH_DEFAULT}}"
export ARTIFACTS_DIR="${WORKSPACE}/artifacts/"
#
# Remove old VENV?
VENV_CLEAN="${VENV_CLEAN:-false}"
#
# Remove ALL apps before upload new?
APPS_CLEAN="${APPS_CLEAN:-false}"
#
# whole path to package will be: GIT_ROOT/APPS_ROOT/PACKAGES_LIST/package
APPS_ROOT="${APPS_ROOT:-/murano-apps/}"
APPS_DIR="${WORKSPACE}/${APPS_ROOT}/"
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

# List of additional packages which will be imported from
# default murano catalog 'http://apps.openstack.org/'
#ADDITIONAL_PACKAGES="com.example.docker.DockerTomcat"



# import default packages_list, if exist
if [ -f "${WORKSPACE}/tools/default_packages_list.sh" ]; then
    if [ -z "${DEFAULT_PACKAGES_LIST}" ]; then
        source "${WORKSPACE}/tools/default_packages_list.sh"
        if [ -z "${PACKAGES_LIST}" ]; then
            echo "Packages list has been imported from default_packages_list.sh file"
            PACKAGES_LIST="${DEFAULT_PACKAGES_LIST}"
        fi
    fi
fi

function prepare_venv() {
    echo 'LOG: Creating python venv for murano-client'
    mkdir -p "${VENV_PATH}"
    virtualenv --system-site-packages  "${VENV_PATH}"
    source "${VENV_PATH}/bin/activate"
    pip install -r test-requirements.txt
    deactivate
}

function build_packages() {
   for pkg_long in ${PACKAGES_LIST}; do
       art_name=$(awk '/FullName:/ {print $2}' "${APPS_DIR}/${pkg_long}/package/manifest.yaml")
       art_file_p="${ARTIFACTS_DIR}/${art_name}.zip"
       pushd "${APPS_DIR}/${pkg_long}/package"
           zip -r "${art_file_p}" ./*
       popd
   done
}

# Body

mkdir -p "${ARTIFACTS_DIR}"
echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > "${ARTIFACTS_DIR}/ci_status_params.txt"

# remove arts from previous run
echo  'LOG: printenv:'
printenv | grep -v "OS_USERNAME\|OS_PASSWORD"
find "${ARTIFACTS_DIR}" -type f -exec rm -fv {} \;

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
    # We don't need do delete old packages, if APPS_CLEAN already did it.
    if [[ "${APPS_CLEAN}" != "true" ]]; then
        echo "LOG: removing old packages..."
        for pkg_long in ${PACKAGES_LIST}; do
            art_name=$(awk '/FullName:/ {print $2}' "${APPS_DIR}/${pkg_long}/package/manifest.yaml")
            art_file_p="${ARTIFACTS_DIR}/${art_name}.zip"
            pkg_id=$(murano package-list --owned |awk "/$art_name/ {print \$2}")
            if [[ -n "${pkg_id}" ]] ; then
                # FIXME remove 'true', after --owned flag will be fixed
                # https://bugs.launchpad.net/mos/+bug/1593279
                murano package-delete "${pkg_id}" || true
            fi
        done
    fi

    # via client and then upload it
    echo "LOG: importing new packages..."
    # We need to be sure, that we load package's only from local files,
    # w\o any upstream dep's. So,use dirty hack to disable dep's resolving on fly
    export MURANO_REPO_URL='http://example.com/'
    echo "LOG: importing all packages from ${ARTIFACTS_DIR}"
    pushd "${ARTIFACTS_DIR}"
       murano package-import ./*.zip --exists-action u
    popd
    # Switch-back do default repo:
    export MURANO_REPO_URL="${DEFAULT_MURANO_REPO_URL}"
    # upload additional packages if needed
    if [ -n "${ADDITIONAL_PACKAGES}" ]; then
        echo "LOG: importing additional packages..."
        for pkg_fqdn in ${ADDITIONAL_PACKAGES}; do
            murano package-import "${pkg_fqdn}" --exists-action u
        done
    fi
    echo "LOG: importing done, final package list:"
    murano package-list --owned
    deactivate
fi

echo FINISHED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" >> "${ARTIFACTS_DIR}/ci_status_params.txt"
