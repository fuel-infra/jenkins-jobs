#!/bin/bash
set -ex

set -o pipefail

get_deb_snapshot() {
    # Debian repos may have format "URL DISTRO COMPONENT1 [COMPONENTN]"
    # Remove quotes and assign values to variables
    read repo_url dist_name components <<< "$(tr -d \" <<< "${@}")"
    # Remove trailing slash
    repo_url=${repo_url%/}
    local snapshot=$(curl -fLsS "${repo_url}.target.txt" | head -1)
    echo "${repo_url%/*}/${snapshot}${dist_name:+ ${dist_name}}${components:+ ${components}}"
}

get_rpm_snapshot() {
    # Remove quotes
    local repo_url="$(tr -d \" <<< "${1}")"
    # Remove trailing slash
    repo_url="${repo_url%/}"
    # Remove architecture
    repo_url="${repo_url%/*}"
    local snapshot="$(curl -fLsS "${repo_url}.target.txt" | head -1)"
    echo "${repo_url%/*}/${snapshot}/x86_64"
}

join () {
    local IFS="${1}"
    shift
    echo "$*"
}

###################### Set required parameters ###############

export VENV_PATH="{VENV_PATH:-${HOME}/venv-nailgun-tests-2.9}"

ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
ENV_NAME="${ENV_NAME:0:68}"

###################### Set RPM Extra Repos ###############

# RPM repository parameters if set are used for all tests
# Append RPM_REPO_URL to EXTRA_RPM_REPOS

# RPM_REPO_URL should be injected from publisher's artifact
# it's non-empty if publisher published rpm binaries
# it'empty when publisher published deb binaries
# it's empty when job started by timer (canary) or user
if [ -n "${RPM_REPO_URL}" ]; then
    EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS:+${EXTRA_RPM_REPOS}|}test-repo,$(get_rpm_snapshot "${RPM_REPO_URL}"),${EXTRA_RPM_REPOS_PRIORITY}"
fi
# EXTRA_RPM_REPOS will not be injected in case when build is trggered by zuul
# it's empty for zuul pipelines
# it's non-empty when job started by timer (canary)
# it's non-empty when triggered by other jenkins job or user
if [ -n "${EXTRA_RPM_REPOS}" ]; then
    EXTRA_RPM_REPOS="$(tr -d \\\" <<< "${EXTRA_RPM_REPOS}")"
    export EXTRA_RPM_REPOS
fi

###################### Get ISO image ###############

# MAGNET_LINK should be set by injecting stable value from devops job
# so expecting always non-empty because if empty, then something is wrong
: "${MAGNET_LINK?}"
if [ -n "${MAGNET_LINK}" ]; then
    echo "MAGNET_LINK=${MAGNET_LINK}"
    ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
else
    echo "*** ERROR: Can not get ISO image! ***"
    exit 1
fi


###################### Set test group ###############

# If job is triggerred by Zuul, job defaults are not applied and TEST_GROUP is empty
# In this case run BVT if there is DEB_REPO_URL, or prepare_slaves_3 otherwise
# the value itself could be set in job
# it's empty for zuul pipelines
# it's non-empty when job started by timer (canary)
# it's non-empty when triggered by other jenkins job or user
if [ -z "${TEST_GROUP}" ]; then
    if [ -n "${DEB_REPO_URL}" -o -n "${EXTRA_DEB_REPOS}" ]; then
        # in case we have some deb
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

# Directive to update fuel's master node
# set value depending on package type being tested
case "${REPO_TYPE}" in
    rpm)
        # required for rpm
        UPDATE_FUEL=true
        # todo:
        # add all dependent repos
        # EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS:+${EXTRA_RPM_REPOS}|}${EXTRA_REPOS}"
    ;;
    deb)
        # not needed for deb
        UPDATE_FUEL=false
        # todo:
        # add all dependent repos
        # EXTRA_DEB_REPOS="${EXTRA_DEB_REPOS:+${EXTRA_DEB_REPOS}|}${EXTRA_REPOS}"
    ;;
    *)
        # must be set from outside
        : "${UPDATE_FUEL?}"
    ;;
esac

if [ "${UPDATE_FUEL}" = "true" ]; then
    # directives for fuel-qa
    # need to update master node
    export UPDATE_MASTER=true
    # with custom repos and packages
    export CUSTOM_ENV=true
    # Note: URL must be ended by a slash symbol!
    # UPDATE_FUEL_MIRROR is a space-separated list of urls

    # see notes for RPM_REPO_URL above:
    # sometimes it's null, so when empty (canary), try to guess
    if [ -z "${RPM_REPO_URL}" ]; then
        # RPM_REPO_PATH will come from publisher artifact when publisher publishes rpm
        # MIRROR_HOST should be set by guess mirror or manually
        export UPDATE_FUEL_MIRROR=$(get_rpm_snapshot "${MIRROR_HOST}/${RPM_REPO_PATH}")/
    else
        # when not canary builds
        export UPDATE_FUEL_MIRROR="${RPM_REPO_URL}/"
    fi
    # todo:
    # It looks like we need to add all rpm extra repos for updating fuel

    # Clear stale package cache
    rm -rvf "${UPDATE_FUEL_PATH:-~/fuel/pkgs}"
fi

###################### Run test ###############

# Append DEB_REPO_URL to EXTRA_DEB_REPOS
# DEB_REPO_URL should come from publisher's artifact
# it's non-empty if publisher published deb binaries
# it's non-empty when job started by timer (canary) or user
# it'empty when publisher published rpm binaries
if [ -n "${DEB_REPO_URL}" ]; then
    # in case when somehow this job has DEB_REPO_URL but have no EXTRA_DEB_REPOS
    # boundary case when job pipeline is being managed by jenkins and not zuul
    # because for zuul EXTRA_DEB_REPOS will be empty
    if [ -z "${EXTRA_DEB_REPOS}" ]; then
        # MIRROR_HOST is set in guess mirror or by hands
        # DEB_REPO_PATH should come from job config injections
        # DEB_DIST_NAME should come from job config injections
        # EXTRA_DEB_REPOS_PRIORITY should come from job config injections
        _deb_repo="${MIRROR_HOST}/${DEB_REPO_PATH} ${DEB_DIST_NAME} main restricted"
        # shellcheck disable=SC2086
        # need to pass all components as separate args
        EXTRA_DEB_REPOS="deb $(get_deb_snapshot ${_deb_repo}),${EXTRA_DEB_REPOS_PRIORITY}"
    fi
    # normal cases:
    # get DEB_REPO_URL from publisher and add it to the extrarepos
    # shellcheck disable=SC2086
    EXTRA_DEB_REPOS="${EXTRA_DEB_REPOS:+${EXTRA_DEB_REPOS}|}deb $(get_deb_snapshot ${DEB_REPO_URL}),${EXTRA_DEB_REPOS_PRIORITY}"
fi

# at this point EXTRA_DEB_REPOS could be mutated and could be not mutated
# it's non-empty if publisher published deb binaries and steps from above is applied
# it's non-empty for timed (canary) and manual builds
# it could be empty only for manual trigger w/o EXTRA_DEB_REPOS
if [ -n "${EXTRA_DEB_REPOS}" ]; then
    EXTRA_DEB_REPOS="$(tr -d \\\" <<< "${EXTRA_DEB_REPOS}")"

    # Each element must be repository description as used in sources.list (prepended by "deb")
    # 1. Split EXTRA_DEB_REPOS to individual repository description
    OLDIFS=${IFS}
    IFS='|'
    DEB_REPOS=( ${EXTRA_DEB_REPOS} )
    IFS=${OLDIFS}

    # 2. Check that first element is word "deb" and prepend it otherwise
    # fixme
    # shellcheck disable=SC2068
    for REPO_NUM in ${!DEB_REPOS[@]}; do
        REPO_ELEMENTS=( ${DEB_REPOS[${REPO_NUM}]} )
        # fixme
        # shellcheck disable=SC2124
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

# print-out env variables for debug
env

# see defaults here: https://github.com/openstack/fuel-qa/blob/master/fuelweb_test/settings.py
pushd fuel-qa
    sh  -x "utils/jenkins/system_tests.sh"  \
           -t test                          \
           -w "${WORKSPACE}/fuel-qa"        \
           -e "${ENV_NAME}"                 \
           -o                               \
           --group="${TEST_GROUP}"          \
           -i "${ISO_PATH}"
popd
