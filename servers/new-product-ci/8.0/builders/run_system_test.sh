#!/bin/bash

set -ex

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

TEST_ISO_JOB_URL="${JENKINS_URL}job/8.0.test_all/"
MIRROR_HOST="http://mirror-pkgs.vm.mirantis.net/pkgs/"

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

rm -rf logs/*

export VENV_PATH=/home/jenkins/venv-nailgun-tests-2.9

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"
