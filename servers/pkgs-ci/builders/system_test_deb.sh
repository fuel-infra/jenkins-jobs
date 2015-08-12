#!/bin/bash

set -ex

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

test -z "${EXTRA_DEB_REPOS}" && EXTRA_DEB_REPOS="deb $(echo "$DEB_REPO_URL" | tr -d \")"

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID:-latest}

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
    bud|bud-ext|undef)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/"
        ;;
    mnv)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org/pkgs/"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest)
            UBUNTU_MIRROR_URL="$(curl ${MIRROR_HOST}ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} trusty main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} trusty-proposed main universe multiverse"
fi

rm -rf logs/*

export VENV_PATH=${VENV_PATH:-/home/jenkins/venv-nailgun-tests-2.9}

ISO_MAGNET_FILE=lastSuccessfulBuild/artifact/magnet_link.txt

# Getting MAGNET_LINK from last built ISO and force rebuild the environment if it has successfully passed smoke test.
ISO_MAGNET_ART=http://jenkins-product.srt.mirantis.net:8080/job/${ISO_JOB_NAME}/${ISO_MAGNET_FILE}

# Check if the artifact with the magnet link exists.
if curl -sl ${ISO_MAGNET_ART} | fgrep "Error 404"; then
    echo "*** ERROR: URL ${ISO_MAGNET_ART} does not exist!"
    exit 1
fi

MAGNET_LINK=`curl -s "${ISO_MAGNET_ART}" | fgrep 'MAGNET_LINK=' | sed 's~.*MAGNET_LINK=~~'`
echo "MAGNET_LINK=${MAGNET_LINK}"

ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}
ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

pushd fuel-qa
sh -x "utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE/fuel-qa" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"
popd
