#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

ACT=0

function update_devops () {
    ACT=1
    VIRTUAL_ENV=/home/jenkins/qa-venv-${1}
    BRANCH=${2}
    REPO=${3:-fuel-qa}

    if [[ -d "${VIRTUAL_ENV}" ]] && [[ "${FORCE_DELETE_DEVOPS}" == "true" ]]; then
    echo "Delete venv from ${VIRTUAL_ENV}"
    rm -rf "${VIRTUAL_ENV}"
    fi

    if [[ -f "${VIRTUAL_ENV}/bin/activate" ]]; then
        echo "Python virtual env exist"
    else
        rm -rf "${VIRTUAL_ENV}"
        virtualenv --no-site-packages "${VIRTUAL_ENV}"
    fi
    source "${VIRTUAL_ENV}/bin/activate"

    #
    # fuel-devops use ~/.devops directory to store log configuration
    # we need to delete log.yaml befeore update to get it in current
    # version
    #
    test -f ~/.devops/log.yaml && rm ~/.devops/log.yaml

    # Prepare requirements file
    if [[ -n "${VENV_REQUIREMENTS}" ]]; then
        echo "Install with custom requirements"
        echo "${VENV_REQUIREMENTS}" >"${WORKSPACE}/venv-requirements.txt"
    else
        if ! curl -fsS "https://raw.githubusercontent.com/openstack/${REPO}/${BRANCH}/fuelweb_test/requirements-devops-source.txt" > "${WORKSPACE}/venv-requirements-devops-source.txt"; then
            echo "Problem with downloading 'fuel-devops' requirements for ${REPO}/${BRANCH}"
            exit 1
        fi

        if ! curl -fsS "https://raw.githubusercontent.com/openstack/${REPO}/${BRANCH}/fuelweb_test/requirements.txt" > "${WORKSPACE}/venv-requirements.txt"; then
            echo "Problem with downloading requirements for ${REPO}/${BRANCH}"
            exit 1
        fi
    fi

    # Upgrade pip inside virtualenv
    pip install pip --upgrade

    pip install -r "${WORKSPACE}/venv-requirements-devops-source.txt" --upgrade
    pip install -r "${WORKSPACE}/venv-requirements.txt" --upgrade
    echo "=============================="
    pip freeze
    echo "=============================="
    django-admin.py syncdb --settings=devops.settings --noinput
    django-admin.py migrate devops --settings=devops.settings --noinput
    deactivate

}

function download_images () {
    ACT=1
    local TARGET_CLOUD_DIR=/home/jenkins/workspace/cloud-images
    mkdir -p ${TARGET_CLOUD_DIR}

    for IMAGE in "${CLOUD_FEDORA}" \
                 "${SAVANNA_IMAGE}" \
                 "${F17_IMAGE}" \
                 "${MURANO_IMAGE}" \
                 "${MURANO_IMAGE_26_02_15}" \
                 "${SAHARA_JUNO_HDP}" \
                 "${SAHARA_JUNO_VANILLA}" \
                 "${SAHARA_KILO_VANILLA}" \
                 "${SAHARA_LIBERTY_VANILLA}" \
                 "${QA_CENTOS_COMPUTE}" \
                 "${QA_CENTOS_CLOUD}" \
                 "${QA_RHEL_COMPUTE}" \
                 "${QA_OL_COMPUTE}" \
                 "${INSTALL_PACKAGES_CENTOS_6_4}" \
                 "${INSTALL_PACKAGES_CENTOS_7_0}" \
                 "${INSTALL_PACKAGES_UBUNTU_12_04}" \
                 "${INSTALL_PACKAGES_UBUNTU_14_04}";
    do
        seedclient.py -d -m "${IMAGE}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}"
    done
}

# Release 6.0
if [[ ${update_release_6_0} == "true" ]]; then
  update_devops "6.0" "stable/6.0" "fuel-main"
fi

# Release 6.1
if [[ ${update_release_6_1} == "true" ]]; then
  update_devops "6.1" "stable/6.1"
fi

# Release 7.0
if [[ ${update_release_7_0} == "true" ]]; then
  update_devops "7.0" "stable/7.0"
fi

# Release 8.0
if [[ ${update_release_8_0} == "true" ]]; then
  update_devops "8.0" "stable/8.0"
fi

# Master branch
if [[ ${update_release_master} == "true" ]]; then
  update_devops "master" "master"
fi

if [[ ${download_images} == "true" ]]; then
  download_images
fi

if [ ${ACT} -eq 0 ]; then
  echo "No action selected!"
  exit 1
fi
