#!/bin/bash

set -ex

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_DIST=${UBUNTU_DIST:-trusty}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net/pkgs/snapshots/"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net/pkgs/snapshots/"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net/pkgs/snapshots/"
        ;;
    poz)
        MIRROR_HOST="http://osci-mirror-poz.poz.mirantis.net/pkgs/snapshots/"
        ;;
    bud)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/snapshots/"
        ;;
    bud-ext)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/snapshots/"
        ;;
    mnv|scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/snapshots/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/pkgs/snapshots/"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest-stable)
            UBUNTU_MIRROR_ID="$(curl -fsS "${TEST_ISO_JOB_URL}lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt" | awk -F '[ =]' '{print $NF}')"
            ;;
        latest)
            UBUNTU_MIRROR_ID=$(curl -sSf "${MIRROR_HOST}ubuntu-${UBUNTU_MIRROR_ID}.target.txt" | sed '1p;d')
            ;;
    esac
    UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"

    MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse"
    if [ "${ENABLE_PROPOSED:-false}" = 'true' ]; then
        UBUNTU_PROPOSED="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
        MIRROR_UBUNTU="${MIRROR_UBUNTU}|${UBUNTU_PROPOSED}"
    fi
    export MIRROR_UBUNTU
fi

if [ "$TEST_FRAMEWORK_URL" != "https://github.com/openstack/fuel-qa.git" ] ; then
  # Redefine path to venv if use non standart test framework
  VENV_PATH="${WORKSPACE}/venv_test"
  export VENV_PATH="${VENV_PATH}"
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

# Check if custom test group is specified
if [[ ! -z "${CUSTOM_TEST_GROUP}" ]]; then
  # Remove leading spaces from CUSTOM_TEST_GROUP
  TEST_GROUP="${CUSTOM_TEST_GROUP##"${CUSTOM_TEST_GROUP%%[![:space:]]*}"}"
  # Remove trailing spaces from CUSTOM_TEST_GROUP
  export TEST_GROUP="${TEST_GROUP%%"${TEST_GROUP##*[![:space:]]}"}"

  # Stop script execution to avoid incorrect command line construction
  # for running system tests if list of test groups contains space symbols
  if [[ "${TEST_GROUP}" =~ [[:space:]] ]]
  then
    echo "List of custom test groups must not contain space symbols." \
         "Please separate groups by commas" >&2
    exit 1
  fi
fi

rm -rf logs/*

export MAKE_SNAPSHOT=${MAKE_SNAPSHOT}
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
echo "${ISO_PATH}"

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
