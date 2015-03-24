export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

ACT=0

function update_devops () {
  ACT=1
  VIRTUAL_ENV=/home/jenkins/venv-nailgun-tests${1}
  REPO_NAME=${2}
  if [ -f ${VIRTUAL_ENV}/bin/activate ]; then
    source ${VIRTUAL_ENV}/bin/activate
    echo "Python virtual env exist"
    pip install -r https://raw.githubusercontent.com/stackforge/${REPO_NAME}/master/fuelweb_test/requirements.txt --upgrade
    django-admin.py syncdb --settings=devops.settings --noinput
    django-admin.py migrate devops --settings=devops.settings --noinput
    deactivate
   else
    rm -rf ${VIRTUAL_ENV}
    virtualenv --system-site-packages  ${VIRTUAL_ENV}
    source ${VIRTUAL_ENV}/bin/activate
    pip install -r https://raw.githubusercontent.com/stackforge/${REPO_NAME}/master/fuelweb_test/requirements.txt --upgrade
    django-admin.py syncdb --settings=devops.settings --noinput
    django-admin.py migrate devops --settings=devops.settings --noinput
    deactivate
  fi
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
}

# DevOps 2.5.x
if [[ ${update_devops_2_5_x} == "true" ]]; then
  update_devops "" "fuel-main"
fi

# DevOps 2.9.x
if [[ ${update_devops_2_9_x} == "true" ]]; then
  update_devops "-2.9" "fuel-qa"
fi

if [[ ${download_images} == "true" ]]; then
  download_images
fi

if [ ${ACT} -eq 0 ]; then
  echo "No action selected!"
  exit 1
fi
