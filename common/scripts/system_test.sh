#!/bin/bash
set -ex

set -o pipefail

get_deb_snapshot() {
    # Remove quotes from input argument(s)
    local INPUT
    INPUT=( $(tr -d \" <<< "${@}") )
    # Ubuntu repos may have format "[deb] URL DISTRO COMPONENT1 [COMPONENTN][,PRIORITY]"
    local deb_prefix=''
    if [ "${INPUT[0]}" = "deb" ]; then
        deb_prefix='deb '
        unset INPUT[0]
    fi
    # Assign values to variables.
    # The last variable - 'components' - will also contain priority if any, but
    # it does not matter here, it will be returned as is
    read -r repo_url dist_name components <<< "${INPUT[@]}"
    # Remove trailing slash
    repo_url=${repo_url%/}
    # Cut version
    repo_version=${repo_url##*/}
    repo_url=${repo_url%/*}
    # Get snapshot
    local snapshot=$(curl -fLsS "${repo_url}/snapshots/${repo_version}-latest.target.txt" | sed '1p; d')
    echo "${deb_prefix}${repo_url}/snapshots/${snapshot} ${dist_name} ${components}"
}

get_rpm_snapshot() {
    # Remove quotes from input argument
    local INPUT
    INPUT=$(tr -d \" <<< "${1}")
    # Centos repos may have format "[NAME,]URL[,PRIORITY]"
    read -r repo_name repo_url priority <<< "${INPUT//,/ }"
    if [ -z "${repo_url}" ]; then
        # Repo does not have extra parameters
        repo_url=${repo_name}
        unset repo_name
    elif [ -z "${priority}" ]; then
        # Two parameters... Do we have repo name or priority?
        if [[ "${repo_url}" =~ ^[0-9]+$ ]]; then
            # repo_url contain only numbers - it is priority
            priority=${repo_url}
            repo_url=${repo_name}
            unset repo_name
        fi
    fi
    # Remove trailing slash
    repo_url="${repo_url%/}"
    # Remove architecture
    repo_url="${repo_url%/*}"
    # Cut component
    repo_component="${repo_url##*/}"
    repo_url=${repo_url%/*}
    # Get snapshot
    local snapshot="$(curl -fLsS "${repo_url}/snapshots/${repo_component}-latest.target.txt" | sed '1p; d')"
    echo "${repo_name:+${repo_name},}${repo_url}/snapshots/${snapshot}/x86_64${priority:+,${priority}}"
}

join () {
    local IFS="${1}"
    shift
    echo "$*"
}

###################### Set required parameters ###############

export VENV_PATH="${VENV_PATH:-${HOME}/venv-nailgun-tests-2.9}"

ENV_NAME="${ENV_PREFIX}.${BUILD_NUMBER}.${BUILD_ID}"
ENV_NAME="${ENV_NAME:0:68}"
echo "export ENV_NAME=\"${ENV_NAME}\"" > "${WORKSPACE}/${DOS_ENV_NAME_PROPS_FILE:=.dos_environment_name}"

###################### Guess how to use EXTRAREPO if given ###############

# EXTRAREPO and REPO_TYPE are injected from builder's artifact
# EXTRAREPO contains URL to repositories with requirements/dependencies
# REPO_TYPE contains repository type - deb/rpm
# it's non-empty for zuul pipelines (per-CR jobs)
# it's empty when job started by timer (canary) or user (no CR and no builder job)
if [ -n "${EXTRAREPO}" ]; then
    if [ "${REPO_TYPE}" = "deb" ] && [ -z "${EXTRA_DEB_REPOS}" ]; then
        EXTRA_DEB_REPOS="${EXTRAREPO}"
    elif [ "${REPO_TYPE}" = "rpm" ] && [ -z "${EXTRA_RPM_REPOS}" ]; then
        EXTRA_RPM_REPOS="${EXTRAREPO}"
    fi
fi

###################### Set RPM Extra Repos ###############

# RPM repository parameters if set are used for all tests

# Append RPM_REPO_URL to EXTRA_RPM_REPOS
# RPM_REPO_URL should be injected from publisher's artifact
# it's non-empty if publisher published rpm binaries
# it'empty when publisher published deb binaries
# it's empty when job started by timer (canary) or user
if [ -n "${RPM_REPO_URL}" ]; then
    EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS:+${EXTRA_RPM_REPOS}|}test,$(get_rpm_snapshot "${RPM_REPO_URL}"),1"
else
    # Find snapshots for all EXTRA_RPM_REPOS
    RPM_REPOS=( ${EXTRA_RPM_REPOS//|/ } )
    RPM_SNAPSHOTS=''
    for RPM_REPO in "${RPM_REPOS[@]}"; do
        RPM_SNAPSHOT=$(get_rpm_snapshot "${RPM_REPO}")
        RPM_SNAPSHOTS="${RPM_SNAPSHOTS:+${RPM_SNAPSHOTS}|}${RPM_SNAPSHOT}"
    done
    # Set EXTRA_RPM_REPOS to snapshot list if any
    if [ -n "${RPM_SNAPSHOTS}" ]; then
        EXTRA_RPM_REPOS="${RPM_SNAPSHOTS}"
    fi
fi
# Remove quotes from EXTRA_RPM_REPOS
# EXTRA_RPM_REPOS will not be injected in case when build is trggered by zuul
# it's empty for zuul pipelines
# it's non-empty when job started by timer (canary)
# it's non-empty when triggered by other jenkins job or user
if [ -n "${EXTRA_RPM_REPOS}" ]; then
    EXTRA_RPM_REPOS="$(tr -d \\\" <<< "${EXTRA_RPM_REPOS}")"
fi
export EXTRA_RPM_REPOS

###################### Get ISO image ###############
if [ "${REBUILD_ISO}" = "true" ]; then
    ###################### Build ISO image ###############
    read -r MIRROR_UBUNTU_METHOD MIRROR_UBUNTU_HOST MIRROR_UBUNTU_ROOT <<< "$(awk '{match($0, "^(.+)://([^/]+)(.*)$", a); print a[1], a[2], a[3]}' <<< "${UBUNTU_MIRROR_URL}")"

    pushd fuel-main
    rm -rf "/var/tmp/yum-${USER}-*"
    make deep_clean
    make iso \
        BUILD_PACKAGES=0 \
        USE_MIRROR="${LOCATION}" \
        MIRROR_FUEL="$(get_rpm_snapshot "http://${REMOTE_REPO_HOST}/${RPM_REPO_PATH}")" \
        EXTRA_RPM_REPOS="${EXTRA_RPM_REPOS//|/ }" \
        MIRROR_MOS_UBUNTU_METHOD="${MIRROR_UBUNTU_METHOD}" \
        MIRROR_MOS_UBUNTU="${MIRROR_UBUNTU_HOST}" \
        MIRROR_MOS_UBUNTU_ROOT="${MIRROR_MOS_UBUNTU_ROOT}" \
        MIRROR_MOS_UBUNTU_SUITE="${MIRROR_MOS_UBUNTU_SUITE}" \
        MIRROR_UBUNTU_METHOD="${MIRROR_UBUNTU_METHOD}" \
        MIRROR_UBUNTU="${MIRROR_UBUNTU_HOST}" \
        MIRROR_UBUNTU_ROOT="${MIRROR_UBUNTU_ROOT}" \
        MIRROR_UBUNTU_SUITE="${UBUNTU_DIST}"
    popd

    ISO_PATH=$(find "${WORKSPACE}/fuel-main/build/artifacts/" -name "*.iso" -print)
else
    ###################### Download ISO image ###############
    if [ -n "${MAGNET_LINK}" ]; then
        echo "MAGNET_LINK=${MAGNET_LINK}"
        ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
    else
        echo "*** ERROR: Can not get ISO image! ***"
        exit 1
    fi
fi

###################### Prepare deb repo parameters ###############

# Append DEB_REPO_URL to EXTRA_DEB_REPOS
# DEB_REPO_URL should come from publisher's artifact
# it's non-empty if publisher published deb binaries
# it's empty when job started by timer (canary) or user
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
        _deb_repo="http://${MIRROR_HOST}/${DEB_REPO_PATH} ${DEB_DIST_NAME} main restricted"
        # shellcheck disable=SC2086
        # need to pass all components as separate args
        EXTRA_DEB_REPOS="deb $(get_deb_snapshot ${_deb_repo}),${EXTRA_DEB_REPOS_PRIORITY}"
    fi
    # normal cases:
    # get DEB_REPO_URL from publisher and add it to the extrarepos
    # shellcheck disable=SC2086
    EXTRA_DEB_REPOS="${EXTRA_DEB_REPOS:+${EXTRA_DEB_REPOS}|}deb $(get_deb_snapshot ${DEB_REPO_URL}),${EXTRA_DEB_REPOS_PRIORITY}"
else
    # Find snapshots for all EXTRA_DEB_REPOS
    OLDIFS=${IFS}
    IFS='|'
    DEB_REPOS=( ${EXTRA_DEB_REPOS} )
    IFS=${OLDIFS}

    DEB_SNAPSHOTS=''
    for DEB_REPO in "${DEB_REPOS[@]}"; do
        DEB_SNAPSHOT=$(get_deb_snapshot "${DEB_REPO}")
        DEB_SNAPSHOTS="${DEB_SNAPSHOTS:+${DEB_SNAPSHOTS}|}${DEB_SNAPSHOT}"
    done
    # Set EXTRA_DEB_REPOS to snapshot list if any
    if [ -n "${DEB_SNAPSHOTS}" ]; then
        EXTRA_DEB_REPOS="${DEB_SNAPSHOTS}"
    fi
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

fi
export EXTRA_DEB_REPOS

###################### Set Fuel update parameters ###############

# Prepare URL of Fuel (RPM) packages
# Note: URL must be ended by a slash symbol!
# UPDATE_FUEL_MIRROR is a space-separated list of urls
if [ -z "${RPM_REPO_URL}" ]; then
    # RPM_REPO_PATH will come from publisher artifact when publisher publishes rpm
    # REMOTE_REPO_HOST is used because some repositories (Fuel/feature-nfv) are not mirrored
    UPDATE_FUEL_MIRROR="$(get_rpm_snapshot "http://${REMOTE_REPO_HOST}/${RPM_REPO_PATH}")/ $(get_rpm_snapshot "http://${REMOTE_REPO_HOST}/${RPM_REPO_PATH%/*/*/*}/proposed/x86_64/")/"
else
    # when not canary builds
    # Prepare list of repositories containig Fuel updates (rpm only)
    FUEL_MIRRORS=""
    for REPO in ${EXTRA_RPM_REPOS//|/ }; do
        # Remove repo name
        REPO=${REPO#*,}
        # Remove repo priority
        REPO=${REPO%,*}
        FUEL_MIRRORS="${FUEL_MIRRORS:+${FUEL_MIRRORS} }${REPO}"
    done
    UPDATE_FUEL_MIRROR="${FUEL_MIRRORS}"
fi

# Clear stale package cache
rm -rvf "${UPDATE_FUEL_PATH:-~/fuel/pkgs}"

# If UPDATE_MASTER is true, given repository is used for package updates as is
# If UPDATE_FUEL is true, packages from given URL are downloaded and installed as needed by test cases
if [ "${UPDATE_FUEL}" = "true" ]; then
    UPDATE_FUEL_MIRROR="${UPDATE_FUEL_MIRROR}/Packages/"
    # Given repo URL with appended 'Packages' can't be used for updates
    UPDATE_MASTER=false
    CUSTOM_ENV=true
else
    # Directive to update fuel's master node
    # set value depending on package type being tested
    if [ "${REPO_TYPE}" = "rpm" ]; then
        UPDATE_MASTER=true
    fi
fi

export UPDATE_MASTER UPDATE_FUEL_MIRROR CUSTOM_ENV

###################### Set test group ###############

# If job is triggerred by Zuul, job defaults are not applied and TEST_GROUP is empty
# In this case run BVT if there is DEB_REPO_URL, or prepare_slaves_3 otherwise
# the value itself could be set in job
# it's empty for zuul pipelines
# it's non-empty when job started by timer (canary)
# it's non-empty when triggered by other jenkins job or user
if [ -z "${TEST_GROUP}" ]; then
    if [ -n "${DEB_REPO_URL}" ] || [ -n "${EXTRA_DEB_REPOS}" ]; then
        # in case we have some deb
        TEST_GROUP=bvt_2
    else
        TEST_GROUP=prepare_slaves_3
    fi
fi

# Checkout specified revision of fuel-qa if set.
if [ -n "${FUEL_QA_COMMIT}" ]; then
    git -C fuel-qa checkout "${FUEL_QA_COMMIT}"
fi

# print-out env variables for debug
env | sort

###################### Run test ###############

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
