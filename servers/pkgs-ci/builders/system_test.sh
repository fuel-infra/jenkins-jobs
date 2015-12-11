#!/bin/bash

set -ex

# receive input in the $RPM_REPO_URL var as "repourl1|repourl2|..."
# and convert to the $EXTRA_RPM_REPOS var as
# EXTRA_RPM_REPOS="repo1,repourl1,priority repo2,repourl2,priority"

if [ -n "${RPM_REPO_URL}" -a -z "${EXTRA_RPM_REPOS}" ]; then
    C=0
    for repo in ${RPM_REPO_URL//|/ }; do
        EXTRA_RPM_REPOS=${EXTRA_RPM_REPOS}repo-$C",$repo,1 "; (( ++C ))
    done
fi

if [ -n "${DEB_REPO_URL}" -a -z "${EXTRA_DEB_REPOS}" ]; then
    EXTRA_DEB_REPOS="deb $(echo "${DEB_REPO_URL}" | tr -d \")"
fi

export EXTRA_RPM_REPOS_PRIORITY=1
export EXTRA_DEB_REPOS_PRIORITY=1052
export EXTRA_RPM_REPOS
export EXTRA_DEB_REPOS

export OPENSTACK_RELEASE

###################### Get MIRROR HOST ###############

UBUNTU_MIRROR_FILE="lastSuccessfulBuild/artifact/ubuntu_mirror_id.txt"
UBUNTU_MIRROR_ART="${PRODUCT_JENKINS_URL:-https://product-ci.infra.mirantis.net}/job/${ISO_JOB_NAME}/${UBUNTU_MIRROR_FILE}"

if MIRROR_RES=$(curl -ksf "${UBUNTU_MIRROR_ART}"); then
    if [ "${MIRROR_RES%=*}" = "UBUNTU_MIRROR_ID" ]; then
        export UBUNTU_MIRROR_ID=${MIRROR_RES#*=}
    fi
fi

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

ENV_NAME=$ENV_PREFIX.$BUILD_NUMBER.$BUILD_ID
ENV_NAME=${ENV_NAME:0:68}

# Build ISO if there is any RPM repos
if [ -n "${EXTRA_RPM_REPOS}" -a "${REBUILD_ISO}" = "true" ]; then
    TEST_GROUP="prepare_slaves_3"

    # Build an ISO with custom repository
    pushd fuel-main
    rm -rf "/var/tmp/yum-${USER}-*"
    make deep_clean
    make -j10 iso USE_MIRROR="${LOCATION}" EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS}"
    popd

    ISO_PATH=$(find "${WORKSPACE}/fuel-main/build/artifacts/" -name "*.iso" -print)
else
    TEST_GROUP="bvt_2"

    # Use last BVT-tested ISO
    ISO_MAGNET_FILE="lastSuccessfulBuild/artifact/magnet_link.txt"

    # Getting MAGNET_LINK from last built ISO and force rebuild the environment if it has successfully passed smoke test.
    ISO_MAGNET_ART="${PRODUCT_JENKINS_URL:-https://product-ci.infra.mirantis.net}/job/${ISO_JOB_NAME}/${ISO_MAGNET_FILE}"

    # Check if the artifact with the magnet link exists.
    if curl -sl "${ISO_MAGNET_ART}" | fgrep "Error 404"; then
        echo "*** ERROR: URL ${ISO_MAGNET_ART} does not exist!"
        exit 1
    fi

    MAGNET_LINK=$(curl -s "${ISO_MAGNET_ART}" | fgrep 'MAGNET_LINK=' | sed 's~.*MAGNET_LINK=~~')
    echo "MAGNET_LINK=${MAGNET_LINK}"

    ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
fi

# In case of RHEL tests we override systest group and set additional parameters
# required for test execution
if [[ ${OS_TYPE} == 'rhel' ]]; then
    TEST_GROUP="rhel.basic"

    export RHEL_IMAGE=qa-centos-compute-2015-12-03.qcow2
    export RHEL_IMAGE_PATH=/home/jenkins/workspace/cloud-images/
    export RHEL_IMAGE_MD5=524136c435d3e17143029b3431e46ae1
    export RHEL_IMAGE_USER=root
    export RHEL_IMAGE_PASSWORD=r00tme
    export CENTOS_DUMMY_DEPLOY=True
fi

pushd fuel-qa
sh -x "utils/jenkins/system_tests.sh" -t test -w "$WORKSPACE/fuel-qa" -e "$ENV_NAME" -o --group="$TEST_GROUP" -i "$ISO_PATH"
popd
