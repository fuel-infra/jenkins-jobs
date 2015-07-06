#!/bin/bash -x

set -o errexit
set -o errtrace
set -o pipefail

function retry_ssh_command {
    for _ in {1..5}; do
      if query_result=$(ssh 2>&1 -o ConnectTimeout=3 "${@}"); then
          echo "${query_result}"
          return 0
      else
          sleep 1
          continue
      fi
    done
    echo 1>&2 "Execution of SSH command 'ssh ${@}' failed."
    echo 1>&2 "${query_result}"
    return 1
}

function get_project_name {
    set +x
    GERRIT_HOST="$1"
    GERRIT_PORT="$2"
    GERRIT_REVIEWER="$3"
    retry_ssh_command -p "${GERRIT_PORT}" "${GERRIT_REVIEWER}@${GERRIT_HOST}" gerrit query "${4}" | sed -rn 's/.*project:\s*(\S+).*/\1/pI'
    set -x
}

function check_project_packages {
    GERRIT_HOST="${1}"
    GERRIT_PORT="${2}"
    GERRIT_REVIEWER="${3}"
    PROJECT_NAME="$(get_project_name "${GERRIT_HOST}" "${GERRIT_PORT}" "${GERRIT_REVIEWER}" "${4}")"
    if [[ "${PROJECT_NAME}" == *"packages/"* ]]; then
        if [[ "${PROJECT_NAME}" != *"${REPO_TYPE}"* ]]; then
            return 1
        fi
    fi
}

function trap_err {
    if shopt -o -q errexit
    then
        echo 1>&2 'Test plan generation failed!'
        exit 1
    fi
}

function generate_testplan {
    case "${ENV_PREFIX}" in
        "ubuntu")
            export OPENSTACK_RELEASE="Ubuntu"
            REPO_TYPE="trusty"
            ;;
        "centos")
            export OPENSTACK_RELEASE="CentOS"
            REPO_TYPE="centos"
            ;;
    esac

    if [[ ${#GERRIT_HOSTS[@]} -gt 0 ]]; then
      declare -a PATCHING_MIRRORS_ARRAY
      declare -a PATCHING_MASTER_MIRRORS_ARRAY
        for GERRIT_HOST in "${GERRIT_HOSTS[@]}"; do
            IFS=','
            for GERRIT_CHANGE_NUMBER in ${GERRIT_REVIEWS[${GERRIT_HOST}]}; do
                UBUNTU_REPO_NAME="trusty-fuel-${FUEL_MILESTONE}-${REPOS_SUFFIX}"
                CENTOS_REPO_NAME="centos-fuel-${FUEL_MILESTONE}-${REPOS_SUFFIX}"
                unset IFS
                if check_project_packages "${GERRIT_HOST}" "${GERRIT_PORTS[${GERRIT_HOST}]}" "${GERRIT_USERS[${GERRIT_HOST}]}" "${GERRIT_CHANGE_NUMBER}"; then
                    if [ "${REPO_TYPE}" == "trusty" ]; then
                        PATCHING_MIRRORS_ARRAY+=("${OSCI_OBS_REPOS_UBUNTU}/${UBUNTU_REPO_NAME}-${GERRIT_CHANGE_NUMBER}/ubuntu")
                    else
                        PATCHING_MIRRORS_ARRAY+=("${OSCI_OBS_REPOS_CENTOS}/${CENTOS_REPO_NAME}-${GERRIT_CHANGE_NUMBER}/centos")
                    fi
                    PATCHING_MASTER_MIRRORS_ARRAY+=("${OSCI_OBS_REPOS_CENTOS}/${CENTOS_REPO_NAME}-${GERRIT_CHANGE_NUMBER}/centos")
                else
                    GERRIT_REVIEWS["${GERRIT_HOST}"]="${GERRIT_REVIEWS[${GERRIT_HOST}]//${GERRIT_CHANGE_NUMBER},/}"
                fi
            done
        done
    else
        echo 1>&2 "*** ERROR: There are no change requests specified, nothing to test. Exiting..."
        exit 1
    fi

    # Check if this custom repository still exists.
    for REPO in "${PATCHING_MIRRORS_ARRAY[@]}"; do
      if [[ "$(curl -s -w %\{http_code\} ${REPO} -o /dev/null)" == "404" ]]; then
          echo "*** ERROR: Custom repository ${REPO} does not exist!"
          exit 1
      fi
    done

    ENV_SUFFIX="testplan_generation"

    ENV_NAME="${TEST_GROUP}-${ENV_PREFIX}-${FUEL_MILESTONE}-${ENV_SUFFIX}"

    export PATCHING_MIRRORS="${PATCHING_MIRRORS_ARRAY[*]}"
    export PATCHING_MASTER_MIRRORS="${PATCHING_MASTER_MIRRORS_ARRAY[*]}"
    export PATCHING_APPLY_TESTS="${WORKSPACE}/patching-tests/"
    export PATCHING_BUG_ID="${BUG_ID}"
    export PATCHING_DISABLE_UPDATES=${PATCHING_DISABLE_UPDATES}

    source "${VENV_PATH}/bin/activate"

    echo -e "OPENSTACK_RELEASE=${OPENSTACK_RELEASE}\n"

    sh -x "${SYSTEM_TESTS}" -k -K -V "${VENV_PATH}" -t test -e "${ENV_NAME}" -i "/etc/issue" -o --group="${TEST_GROUP}" -w "${FUEL_WORKSPACE}" -o --show-plan

    IFS=','
    PATCHING_CUSTOM_TESTS=($CUSTOM_TESTS)
    for PATCHING_CUSTOM_TEST in ${PATCHING_CUSTOM_TESTS[@]}; do
        export PATCHING_CUSTOM_TEST
        sh -x "${SYSTEM_TESTS}" -k -K -V "${VENV_PATH}" -t test -e "${ENV_NAME}" -i "/etc/issue" -o --group="${TEST_GROUP}" -w "${FUEL_WORKSPACE}" -o --show-plan
    done
}

trap trap_err ERR

rm -f "${TESTPLAN_RAW_FILE}"
if [ ! -f "parameters.txt" ]; then
    echo 1>&2 'Additional parameters (parameters.txt file) not found!'
    exit 1
fi
source "parameters.txt"
FUEL_WORKSPACE="${WORKSPACE}/fuel-qa"
export VENV_PATH="${PYTHON_VENV}"
export SYSTEM_TESTS="${FUEL_WORKSPACE}/utils/jenkins/system_tests.sh"
unset GERRIT_HOSTS
declare -a GERRIT_HOSTS
declare -A GERRIT_PORTS
declare -A GERRIT_USERS
declare -A GERRIT_REVIEWS

for GERRIT_ID in $(seq 1 "${GERRIT_HOSTS_COUNT}"); do
    GERRIT_HOST_PARAMS=$(eval echo "\$GERRIT_HOST${GERRIT_ID}")
    IFS=':'
    GERRIT_HOST_PARAMS=(${GERRIT_HOST_PARAMS})
    unset IFS
    GERRIT_HOST="${GERRIT_HOST_PARAMS[0]}"
    GERRIT_HOSTS+=("${GERRIT_HOST}")
    GERRIT_PORTS["${GERRIT_HOST}"]="${GERRIT_HOST_PARAMS[1]}"
    GERRIT_USERS["${GERRIT_HOST}"]="${GERRIT_HOST_PARAMS[2]}"
    GERRIT_REVIEWS["${GERRIT_HOST}"]=$(eval echo "\$GERRIT_CHANGES_NUMBERS${GERRIT_ID}")
done

if ${ENABLED_DEB_PATCHING} || ${ENABLED_DEB_GA_PATCHING}; then
    export ENV_PREFIX="ubuntu"
    export TEST_GROUP="patching_environment"
    generate_testplan >> ${TESTPLAN_RAW_FILE}
fi

if ${ENABLED_UBUNTU_MASTER_PATCHING} || ${ENABLED_UBUNTU_MASTER_GA_PATCHING}; then
    export ENV_PREFIX="ubuntu"
    export TEST_GROUP="patching_master"
    generate_testplan >> ${TESTPLAN_RAW_FILE}
fi

if ${ENABLED_RPM_PATCHING} || ${ENABLED_RPM_GA_PATCHING}; then
    export ENV_PREFIX="centos"
    export TEST_GROUP="patching_environment"
    generate_testplan >> ${TESTPLAN_RAW_FILE}
fi

if ${ENABLED_CENTOS_MASTER_PATCHING} || ${ENABLED_CENTOS_MASTER_GA_PATCHING}; then
    export ENV_PREFIX="centos"
    export TEST_GROUP="patching_master"
    generate_testplan >> ${TESTPLAN_RAW_FILE}
fi

echo "[<a href=\"/job/${JOB_NAME}/${BUILD_NUMBER}/artifact/${TESTPLAN_HTML_FILE}\">TestPlan</a>]"