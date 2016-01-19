#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

ACT=0

function update_devops () {
  ACT=1
  VIRTUAL_ENV=/home/jenkins/venv-nailgun-tests${1}
  REPO_NAME=${2}
  BRANCH=${3}

  if [ -f ${VIRTUAL_ENV}/bin/activate ]; then
    source ${VIRTUAL_ENV}/bin/activate
    echo "Python virtual env exist"
  else
    rm -rf ${VIRTUAL_ENV}
    virtualenv --system-site-packages  ${VIRTUAL_ENV}
    source ${VIRTUAL_ENV}/bin/activate
  fi

  # Prepare requirements file
  if [[ -n "${VENV_REQUIREMENTS}" ]]; then
    echo "Install with custom requirements"
    echo "${VENV_REQUIREMENTS}" >"${WORKSPACE}/venv-requirements.txt"
  else
    if ! curl -fsS "https://raw.githubusercontent.com/openstack/${REPO_NAME}/${BRANCH}/fuelweb_test/requirements.txt" > "${WORKSPACE}/venv-requirements.txt"; then
      echo "Problem with downloading requirements"
      exit 1
    fi
  fi

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
  TARGET_CLOUD_DIR=/home/jenkins/workspace/cloud-images
  mkdir -p ${TARGET_CLOUD_DIR}

  TMP_CLOUD_FEDORA=$(seedclient-wrapper -d -m "${CLOUD_FEDORA}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_SAVANNA_IMAGE=$(seedclient-wrapper -d -m "${SAVANNA_IMAGE}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_F17_IMAGE=$(seedclient-wrapper -d -m "${F17_IMAGE}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_MURANO_IMAGE=$(seedclient-wrapper -d -m "${MURANO_IMAGE}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_MURANO_IMAGE_26_02_15=$(seedclient-wrapper -d -m "${MURANO_IMAGE_26_02_15}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")

  TMP_SAHARA_JUNO_HDP=$(seedclient-wrapper -d -m "${SAHARA_JUNO_HDP}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_SAHARA_JUNO_VANILLA=$(seedclient-wrapper -d -m "${SAHARA_JUNO_VANILLA}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_SAHARA_KILO_VANILLA=$(seedclient-wrapper -d -m "${SAHARA_KILO_VANILLA}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
  TMP_SAHARA_LIBERTY_VANILLA=$(seedclient-wrapper -d -m "${SAHARA_LIBERTY_VANILLA}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")

  TMP_QA_CENTOS_COMPUTE=$(seedclient-wrapper -d -m "${QA_CENTOS_COMPUTE}" -v --force-set-symlink -o "${TARGET_CLOUD_DIR}")
}

# DevOps 2.5.x
if [[ ${update_devops_2_5_x} == "true" ]]; then
  update_devops "" "fuel-main" "stable/6.1"
fi

# DevOps 2.9.x
if [[ ${update_devops_2_9_x} == "true" ]]; then
  update_devops "-2.9" "fuel-qa" "master"
fi

# Release 6.1
if [[ ${update_release_6_1} == "true" ]]; then
  update_devops "-release-6.1" "fuel-qa" "stable/6.1"
fi

# Release 7.0
if [[ ${update_release_7_0} == "true" ]]; then
  update_devops "-release-7.0" "fuel-qa" "stable/7.0"
fi

# Release 8.0
if [[ ${update_release_8_0} == "true" ]]; then
  update_devops "-release-8.0" "fuel-qa" "stable/8.0"
fi

if [[ ${download_images} == "true" ]]; then
  download_images
fi

if [ ${ACT} -eq 0 ]; then
  echo "No action selected!"
  exit 1
fi
