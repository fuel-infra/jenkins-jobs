#!/bin/bash

set -ex

echo STARTED_TIME="$(date -u +'%Y-%m-%dT%H:%M:%S')" > ci_status_params.txt

# receive input in the $RPM_REPO_URL var as "repourl1|repourl2|..."
# and convert to the $EXTRA_RPM_REPOS var as
# EXTRA_RPM_REPOS="repo1,repourl1,priority repo2,repourl2,priority"

if [ -z "${EXTRA_RPM_REPOS}" ]; then
C=0; for repo in ${RPM_REPO_URL//|/ }; do
EXTRA_RPM_REPOS=${EXTRA_RPM_REPOS}repo-$C",$repo,1 "; (( ++C ))
done
fi
export EXTRA_RPM_REPOS

EXTRA_RPM_REPOS_PRIORITY=1

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location)
LOCATION=${LOCATION_FACT:-cz}
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
        LOCATION="hrk"
        ;;
    poz|bud|bud-ext|undef)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org/pkgs/"
        LOCATION="cz"
        ;;
    mnv)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org/pkgs/"
        LOCATION="usa"
        ;;
esac

# Build an ISO with custom repository
pushd fuel-main
make deep_clean
make -j10 iso USE_MIRROR="${LOCATION}" EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS}"
popd

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

ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}
ISO_PATH=$(find ${WORKSPACE}/fuel-main/build/artifacts/ -name *.iso -print)

pushd fuel-qa
sh -x "utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE/fuel-qa" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"
popd
