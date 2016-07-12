#!/bin/bash

set -ex

TEST_ISO_JOB_URL="https://product-ci.infra.mirantis.net/job/9.0.test_all/"

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/pkgs/"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/pkgs/"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/pkgs/"
        ;;
    poz)
        MIRROR_HOST="http://osci-mirror-poz.poz.mirantis.net/pkgs/"
        ;;
    bud)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/"
        ;;
    bud-ext)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/"
        ;;
    mnv|scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/pkgs/"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest-stable)
            UBUNTU_MIRROR_ID="$(curl -fsS "${TEST_ISO_JOB_URL}lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" | awk -F '[ =]' '{print $NF}')"
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
            ;;
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
fi

if [[ "${NETWORK_MODE}" == "Neutron/VLAN" ]]; then
  export NEUTRON_ENABLE="true"
  export NEUTRON_SEGMENT_TYPE="vlan"
fi

if [[ "${NETWORK_MODE}" == "Neutron/GRE" ]]; then
  export NEUTRON_ENABLE="true"
  export NEUTRON_SEGMENT_TYPE="gre"
fi

if [[ "${NETWORK_MODE}" == "Neutron/VXLAN" ]]; then
  export NEUTRON_ENABLE="true"
  export NEUTRON_SEGMENT_TYPE="tun"
fi

# Checking gerrit commits for fuel-qa
if [[ "${fuel_qa_gerrit_commit}" != "none" ]] ; then
  for commit in ${fuel_qa_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-qa "${commit}" && git cherry-pick FETCH_HEAD
  done
fi

# LP Bug:1549769 , seedclient should be started without activated virtualenv
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
echo "${ISO_PATH}"

export VENV_PATH="/home/jenkins/venv-nailgun-tests-2.9"

# Checking gerrit commits for fuel-devops
if [[ ${FUEL_DEVOPS_COMMIT} != "none" ]] ; then
  export VENV_PATH="${WORKSPACE}/devops-venv"
  virtualenv "${VENV_PATH}"
  . "${VENV_PATH}/bin/activate"
  pip install -r ./fuelweb_test/requirements-devops-source.txt --upgrade
  pip install -r ./fuelweb_test/requirements.txt --upgrade
  git clone https://github.com/openstack/fuel-devops.git
  cd ./fuel-devops
  git checkout "${FUEL_DEVOPS_COMMIT}"
  if [[ "${fuel_devops_gerrit_commit}" != "none" ]] ; then
    for devops_commit in ${fuel_devops_gerrit_commit} ; do
      git fetch https://review.openstack.org/openstack/fuel-devops "${devops_commit}" && git cherry-pick FETCH_HEAD
    done
  fi
  pip uninstall -y fuel-devops
  pip install ./ --upgrade
  cd "${WORKSPACE}"
  export DEVOPS_DB_NAME=${VENV_PATH}/fuel_devops.sqlite3
  export DEVOPS_DB_ENGINE="django.db.backends.sqlite3"
  echo "export DEVOPS_DB_ENGINE='django.db.backends.sqlite3'" >> "${VENV_PATH}/bin/activate"
  echo "export DEVOPS_DB_NAME=\${VIRTUAL_ENV}/fuel_devops.sqlite3" >> "${VENV_PATH}/bin/activate"
# Ability to unset custom variables to avoid confusion with variables in case of manual check of job results.
  sed -i "s/\(unset VIRTUAL_ENV\)/\1 DEVOPS_DB_ENGINE DEVOPS_DB_NAME/" "${VENV_PATH}/bin/activate"
  django-admin.py syncdb --settings=devops.settings
  django-admin.py migrate devops --settings=devops.settings
fi

# Check if custom test group is specified
if [[ ! -z "${CUSTOM_TEST_GROUP}" ]]; then
  export TEST_GROUP="${CUSTOM_TEST_GROUP}"
fi


rm -rf logs/*

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT}

# Fix parameters for ha_neutron_destructive test
if [[ "${TEST_GROUP}" == "ha_neutron_destructive" ]]; then
  export NEUTRON_ENABLE="true"
fi

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
export ENV_NAME=${ENV_NAME:0:68}
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

export PATH_TO_CERT="${WORKSPACE}/${ENV_NAME}.crt"
export PATH_TO_PEM="${WORKSPACE}/${ENV_NAME}.pem"

export OPENSTACK_RELEASE="${OPENSTACK_RELEASE}"

echo "Description string: ${TEST_GROUP} on ${NODE_NAME}: ${ENV_NAME}"

sh -x "utils/jenkins/system_tests.sh" \
  -t test \
  -w "${WORKSPACE}" \
  -V "${VENV_PATH}" \
  -j "${JOB_NAME}" \
  -o --group="${TEST_GROUP}" \
  -i "${ISO_PATH}"

test_exit_code=$?

#Removing old env
if [[ ${FUEL_DEVOPS_COMMIT} != "none" ]] ; then
  dos.py erase "$ENV_NAME"
fi

exit ${test_exit_code}
