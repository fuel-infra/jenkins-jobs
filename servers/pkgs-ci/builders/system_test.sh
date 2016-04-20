#!/bin/bash

set -o errexit
set -o pipefail
set -o xtrace

get_deb_snapshot() {
    # Debian repos may have format "URL DISTRO COMPONENT1 [COMPONENTN]"
    # Remove quotes and assign values to variables
    read repo_url dist_name components <<< $(tr -d \" <<< "${@}")
    # Remove trailing slash
    repo_url=${repo_url%/}
    local snapshot=$(curl -fLsS "${repo_url}.target.txt" | head -1)
    echo "${repo_url%/*}/${snapshot}${dist_name:+ ${dist_name}}${components:+ ${components}}"
}

get_rpm_snapshot() {
    # Remove quotes
    local repo_url=$(tr -d \" <<< "${1}")
    # Remove trailing slash
    repo_url=${repo_url%/}
    # Remove architecture
    repo_url=${repo_url%/*}
    local snapshot=$(curl -fLsS "${repo_url}.target.txt" | head -1)
    echo "${repo_url%/*}/${snapshot}/x86_64"
}

join () {
    local IFS="${1}"
    shift
    echo "$*"
}

###################### Set defaults ###############
# When job is triggerred by Zuul, parameters for job are set by Zuul, and job
# defaults are not applied.

export EXTRA_RPM_REPOS_PRIORITY=${EXTRA_RPM_REPOS_PRIORITY:-1}
export EXTRA_DEB_REPOS_PRIORITY=${EXTRA_DEB_REPOS_PRIORITY:-1052}

###################### Set required parameters ###############

export VENV_PATH=${VENV_PATH:-${HOME}/venv-nailgun-tests-2.9}

ENV_NAME=${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}
ENV_NAME=${ENV_NAME:0:68}

###################### Get MIRROR HOST ###############

LOCATION_FACT=$(facter --external-dir /etc/facter/facts.d/ location || :)
LOCATION=${LOCATION_FACT:-bud}
UBUNTU_MIRROR_ID=${UBUNTU_MIRROR_ID:-latest}

case "${LOCATION}" in
    srt)
        MIRROR_HOST="http://osci-mirror-srt.srt.mirantis.net"
        ;;
    msk)
        MIRROR_HOST="http://osci-mirror-msk.msk.mirantis.net"
        ;;
    kha)
        MIRROR_HOST="http://osci-mirror-kha.kha.mirantis.net"
        LOCATION="hrk"
        ;;
    poz|bud|bud-ext|undef)
        MIRROR_HOST="http://mirror.seed-cz1.fuel-infra.org"
        LOCATION="cz"
        ;;
    mnv|scc)
        MIRROR_HOST="http://mirror.seed-us1.fuel-infra.org"
        LOCATION="usa"
        ;;
    *)
        MIRROR_HOST="http://mirror.fuel-infra.org"
esac

###################### Get MIRROR_UBUNTU ###############

if [[ ! "${MIRROR_UBUNTU}" ]]; then

    case "${UBUNTU_MIRROR_ID}" in
        latest)
            UBUNTU_MIRROR_URL="$(curl -fLsS ${MIRROR_HOST}/pkgs/ubuntu-latest.htm)"
            ;;
        *)
            UBUNTU_MIRROR_URL="${MIRROR_HOST}/pkgs/${UBUNTU_MIRROR_ID}/"
    esac

    export MIRROR_UBUNTU="deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST} main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-updates main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-security main universe multiverse|deb ${UBUNTU_MIRROR_URL} ${UBUNTU_DIST}-proposed main universe multiverse"
fi

###################### Get ISO image ###############

# RPM repository parameters if set are used for all tests
# Append RPM_REPO_URL to EXTRA_RPM_REPOS
if [ -n "${RPM_REPO_URL}" ]; then
    EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS:+${EXTRA_RPM_REPOS}|}test-repo,$(get_rpm_snapshot "${RPM_REPO_URL}"),${EXTRA_RPM_REPOS_PRIORITY}"
fi

if [ -n "${EXTRA_RPM_REPOS}" ]; then
    EXTRA_RPM_REPOS="$(tr -d \\\" <<< ${EXTRA_RPM_REPOS})"
    export EXTRA_RPM_REPOS
fi

if [ "${REBUILD_ISO}" = "true" ]; then
    # Build an ISO with custom repository

    read MIRROR_UBUNTU_METHOD MIRROR_UBUNTU_HOST MIRROR_UBUNTU_ROOT <<< $(awk '{match($0, "^(.+)://([^/]+)(.*)$", a); print a[1], a[2], a[3]}' <<< "${UBUNTU_MIRROR_URL}")

    pushd fuel-main
    rm -rf "/var/tmp/yum-${USER}-*"
    make deep_clean
    make iso \
        USE_MIRROR="${LOCATION}" \
        MIRROR_FUEL=$(get_rpm_snapshot "${MIRROR_HOST}/${RPM_REPO_PATH}") \
        EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS}" \
        MIRROR_MOS_UBUNTU_METHOD="${MIRROR_UBUNTU_METHOD}" \
        MIRROR_MOS_UBUNTU="${MIRROR_UBUNTU_HOST}" \
        MIRROR_UBUNTU_METHOD="${MIRROR_UBUNTU_METHOD}" \
        MIRROR_UBUNTU="${MIRROR_UBUNTU_HOST}" \
        MIRROR_UBUNTU_ROOT="${MIRROR_UBUNTU_ROOT}" \
        MIRROR_UBUNTU_SUITE="${UBUNTU_DIST}"
    popd

    ISO_PATH=$(find "${WORKSPACE}/fuel-main/build/artifacts/" -name "*.iso" -print)
else
    if [ -z "${MAGNET_LINK}" ]; then
        # Use last BVT-tested ISO
        ISO_MAGNET_FILE="lastSuccessfulBuild/artifact/magnet_link.txt"

        # Getting MAGNET_LINK from last built ISO and force rebuild the environment if it has successfully passed smoke test.
        ISO_MAGNET_ART="${PRODUCT_JENKINS_URL}/job/${ISO_JOB_NAME}/${ISO_MAGNET_FILE}"

        MAGNET_LINK=$(curl -kLs "${ISO_MAGNET_ART}" | awk '/^MAGNET_LINK=/ {print gensub(/^[^=]+=/,"",1)}')
    fi
    if [ -n "${MAGNET_LINK}" ]; then
        echo "MAGNET_LINK=${MAGNET_LINK}"
        ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
    else
        echo "*** ERROR: Can not get ISO image! ***"
        exit 1
    fi
fi

###################### Set test group ###############

# If job is triggerred by Zuul, job defaults are not applied and TEST_GROUP is empty
# In this case run BVT if there is DEB_REPO_URL, or prepare_slaves_3 otherwise
if [ -z "${TEST_GROUP}" ]; then
    if [ -n "${DEB_REPO_URL}" -o -n "${EXTRA_DEB_REPOS}" ]; then
        TEST_GROUP=bvt_2
    else
        TEST_GROUP=prepare_slaves_3
    fi
fi

# In case of RHEL tests we override systest group and set additional parameters
# required for test execution
if [[ ${OS_TYPE} == 'rhel' ]]; then
    TEST_GROUP="rhel.basic"

    export OPENSTACK_RELEASE=ubuntu
    export RHEL_IMAGE=centos7_devops_04022016.qcow2
    export RHEL_IMAGE_PATH=/home/jenkins/workspace/cloud-images/
    export RHEL_IMAGE_MD5=21415760de49e6b0dc5666420b1cbd47
    export RHEL_IMAGE_USER=root
    export RHEL_IMAGE_PASSWORD=r00tme
    export CENTOS_DUMMY_DEPLOY=True
fi

###################### Set Fuel update parameters ###############

if [ "${UPDATE_FUEL}" = "true" ]; then
    export UPDATE_MASTER=true
    export CUSTOM_ENV=true
    # Note: URL must be ended by a slash symbol!
    if [ -z "${RPM_REPO_URL}" ]; then
        export UPDATE_FUEL_MIRROR=$(get_rpm_snapshot "${MIRROR_HOST}/${RPM_REPO_PATH}")/
    else
        export UPDATE_FUEL_MIRROR="${RPM_REPO_URL}/"
    fi
    # Clear stale package cache
    rm -rvf ${UPDATE_FUEL_PATH:-~/fuel/pkgs}
fi

###################### Run test ###############

# Append DEB_REPO_URL to EXTRA_DEB_REPOS
if [ -n "${DEB_REPO_URL}" ]; then
    if [ -z "${EXTRA_DEB_REPOS}" ]; then
        EXTRA_DEB_REPOS="deb $(get_deb_snapshot ${MIRROR_HOST}/${DEB_REPO_PATH} ${DEB_DIST_NAME} main restricted),${EXTRA_DEB_REPOS_PRIORITY}"
    fi
    EXTRA_DEB_REPOS="${EXTRA_DEB_REPOS:+${EXTRA_DEB_REPOS}|}deb $(get_deb_snapshot ${DEB_REPO_URL}),${EXTRA_DEB_REPOS_PRIORITY}"
fi

if [ -n "${EXTRA_DEB_REPOS}" ]; then
    EXTRA_DEB_REPOS="$(tr -d \\\" <<< ${EXTRA_DEB_REPOS})"

    # Each element must be repository description as used in sources.list (prepended by "deb")
    # 1. Split EXTRA_DEB_REPOS to individual repository description
    OLDIFS=${IFS}
    IFS='|'
    DEB_REPOS=( ${EXTRA_DEB_REPOS} )
    IFS=${OLDIFS}

    # 2. Check that first element is word "deb" and prepend it otherwise
    for REPO_NUM in ${!DEB_REPOS[@]}; do
        REPO_ELEMENTS=( ${DEB_REPOS[${REPO_NUM}]} )
        test "${REPO_ELEMENTS[0]}" != "deb" && DEB_REPOS[${REPO_NUM}]="deb ${REPO_ELEMENTS[@]}"
    done

    # 3. Join repository descriptions to EXTRA_DEB_REPOS
    EXTRA_DEB_REPOS=$( join '|' "${DEB_REPOS[@]}" )

    export EXTRA_DEB_REPOS
fi

# Checkout specified revision of fuel-qa if set.
if [ -n "${FUEL_QA_COMMIT}" ]; then
    git -C fuel-qa checkout "${FUEL_QA_COMMIT}"
fi

pushd fuel-qa
sh -x "utils/jenkins/system_tests.sh" -t test -w "${WORKSPACE}/fuel-qa" -e "${ENV_NAME}" -o --group="${TEST_GROUP}" -i "${ISO_PATH}"
popd
