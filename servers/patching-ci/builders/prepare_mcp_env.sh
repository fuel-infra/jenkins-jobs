#!/bin/bash

set -ex

function download_images () {
    local TARGET_CLOUD_DIR=/home/jenkins/images
    mkdir -p ${TARGET_CLOUD_DIR}

    #for IMAGE in "${MCP_CLOUDINIT_IMAGE}";
    #do
    IMAGE="${MCP_CLOUDINIT_IMAGE}"
    local ofilename=$(basename "${IMAGE}")
    wget "${IMAGE}" -O "${TARGET_CLOUD_DIR}/${ofilename}"
    #done
}

function update_mcp () {
    VIRTUAL_ENV="/home/jenkins/qa-venv-mcp"
    SQLITE_DIR="/home/jenkins/.sqlite"
    mkdir -p "${SQLITE_DIR}"

    if [[ -d "${VIRTUAL_ENV}" ]] && [[ "${recreate_venv}" == "true" ]]; then
        echo "Delete venv from ${VIRTUAL_ENV}"
        rm -rf "${VIRTUAL_ENV}"
    fi

    if [[ -f "${VIRTUAL_ENV}/bin/activate" ]]; then
        echo "Python virtual env exist"
    else
        rm -rf "${VIRTUAL_ENV}"
        virtualenv "${VIRTUAL_ENV}"
        echo "export DEVOPS_DB_NAME=\"${SQLITE_DIR}/fuel-devops3.sqlite\"" >> "${VIRTUAL_ENV}/bin/activate"
        echo "export DEVOPS_DB_ENGINE=django.db.backends.sqlite3" >> "${VIRTUAL_ENV}/bin/activate"
    fi
    source "${VIRTUAL_ENV}/bin/activate"


    if [[ -n "${VENV_REQUIREMENTS}" ]]; then
        echo "Install with custom requirements"
        echo "${VENV_REQUIREMENTS}" >"${WORKSPACE}/venv-requirements.txt"
    else
        if ! curl -fsS "https://raw.githubusercontent.com/Mirantis/tcp-qa/master/tcp_tests/requirements.txt" > "${WORKSPACE}/venv-requirements.txt"; then
            echo "Problem with downloading requirements"
            exit 1
        fi
    fi

    pip install -U pip
    pip install -U -r "${WORKSPACE}/venv-requirements.txt"
    echo "=============================="
    pip freeze
    echo "=============================="
    django-admin.py syncdb --settings=devops.settings --noinput
    django-admin.py migrate devops --settings=devops.settings --noinput
    deactivate
}


# Release mcp
if [[ ${update_mcp} == "true" ]]; then
    update_mcp
fi

if [[ ${download_images} == "true" ]]; then
    download_images
fi
