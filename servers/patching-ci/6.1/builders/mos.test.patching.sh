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

function vote {
    set +x
    GERRIT_HOST="${1}"
    GERRIT_PORT="${2}"
    GERRIT_REVIEWER="${3}"
    shift 3
    retry_ssh_command -p "${GERRIT_PORT}" "${GERRIT_REVIEWER}@${GERRIT_HOST}" gerrit review "${@}"
    set -x
}

function get_latest_patchset {
    set +x
    GERRIT_HOST="${1}"
    GERRIT_PORT="${2}"
    GERRIT_REVIEWER="${3}"
    retry_ssh_command -p "${GERRIT_PORT}" "${GERRIT_REVIEWER}@${GERRIT_HOST}" gerrit query --current-patch-set "${4}" | awk '/currentPatchSet/{getline; if ($1 ~ /number:/) print $NF}'
    set -x
}

function get_bug_from_commit_message {
    set +x
    GERRIT_HOST="${1}"
    GERRIT_PORT="${2}"
    GERRIT_REVIEWER="${3}"
    retry_ssh_command -p "${GERRIT_PORT}" "${GERRIT_REVIEWER}@${GERRIT_HOST}" gerrit query --commit-message "${4}" | sed -rn 's/.*(closes|partial)-bug:\s*#([0-9]+)\b.*/\2/pI'
    set -x
}

function get_project_name {
    set +x
    GERRIT_HOST="$1"
    GERRIT_PORT="$2"
    GERRIT_REVIEWER="$3"
    retry_ssh_command -p "${GERRIT_PORT}" "${GERRIT_REVIEWER}@${GERRIT_HOST}" gerrit query "${4}" | sed -rn 's/.*project:\s*(\S+).*/\1/pI'
    set -x
}

function gerrit_review {
    set +x
    if [ ${#GERRIT_HOSTS[@]} -gt 0 ]; then
        for GERRIT_HOST in "${GERRIT_HOSTS[@]}"; do
            IFS=','
            for GERRIT_CHANGE_NUMBER in ${GERRIT_REVIEWS[${GERRIT_HOST}]}; do
                unset IFS
                GERRIT_PATCHSET_NUMBER="$(get_latest_patchset "${GERRIT_HOST}" "${GERRIT_PORTS[${GERRIT_HOST}]}" "${GERRIT_USERS[${GERRIT_HOST}]}" "${GERRIT_CHANGE_NUMBER}")"
                GERRIT_CMD="${GERRIT_CHANGE_NUMBER},${GERRIT_PATCHSET_NUMBER}"
                vote "${GERRIT_HOST}" "${GERRIT_PORTS[${GERRIT_HOST}]}" "${GERRIT_USERS[${GERRIT_HOST}]}" "${GERRIT_CMD}" "${@}"
            done
        done
    else
        retry_ssh_command -p "${GERRIT_PORT}" "${GERRIT_REVIEWER}@${GERRIT_HOST}" gerrit review "${GERRIT_PATCHSET_REVISION}" "${@}"
    fi
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
        gerrit_review -m "'* ${JOB_NAME} ${BUILD_URL} : FAILURE'" --verified=-1
    fi
}

trap trap_err ERR

FUEL_WORKSPACE="${WORKSPACE}/fuel-qa"
export VENV_PATH="${PYTHON_VENV}"
export SYSTEM_TESTS="${FUEL_WORKSPACE}/utils/jenkins/system_tests.sh"
export FUEL_STATS_ENABLED="false"
export ADMIN_NODE_MEMORY="2560"
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
    GERRIT_USERS["${GERRIT_HOST}"]="${GERRIT_REVIEWER}"
    GERRIT_REVIEWS["${GERRIT_HOST}"]=$(eval echo "\$GERRIT_CHANGES_NUMBERS${GERRIT_ID}")
done

if ! eval \$${ENABLE_VAR}; then
    gerrit_review --message "'* ${JOB_NAME} ${BUILD_URL} : SKIPPED'" --verified "0"
    exit 0
fi

case "${ENV_PREFIX}" in
    "ubuntu")
        export OPENSTACK_RELEASE="Ubuntu"
        REPO_TYPE=${REPO_TYPE:-"trusty"}
        ;;
    "centos")
        export OPENSTACK_RELEASE="CentOS"
        REPO_TYPE=${REPO_TYPE:-"centos"}
        ;;
esac

cd "${FUEL_WORKSPACE}" && { find "./logs/" -type f -delete ||:; }

if [[ ${#GERRIT_HOSTS[@]} -gt 0 ]]; then
  declare -a PATCHING_MIRRORS_ARRAY
  declare -a PATCHING_MASTER_MIRRORS_ARRAY
    for GERRIT_HOST in "${GERRIT_HOSTS[@]}"; do
        IFS=','
        for GERRIT_CHANGE_NUMBER in ${GERRIT_REVIEWS[${GERRIT_HOST}]}; do
            UBUNTU_REPO_NAME="trusty-fuel-${FUEL_MILESTONE}-stable"
            CENTOS_REPO_NAME="centos-fuel-${FUEL_MILESTONE}-stable"
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
      gerrit_review --message "'* ${JOB_NAME} ${BUILD_URL} : FAILURE'" --verified "-1"
      exit 1
  fi
done

ENV_NAME="${TEST_GROUP}-${ENV_PREFIX}-${FUEL_MILESTONE}"

if [ -n "${MAGNET_LINK}" ]; then
    ISO_PATH="$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")"
else
    echo 1>&2 "Magnet link to ISO isn't specified. Exiting..."
    exit 1
fi

ISO_NAME="$(basename "$ISO_PATH")"
ISO_VERSION="$(echo "${ISO_NAME}"| cut -d '-' -f 2-3)"

CHECK_REVIEWS_BUGS=true
for GERRIT_HOST in "${GERRIT_HOSTS[@]}"; do
    IFS=','
    for GERRIT_CHANGE_NUMBER in ${GERRIT_REVIEWS[${GERRIT_HOST}]}; do
        unset IFS
        CHANGE_BUG_IDS="$(get_bug_from_commit_message "${GERRIT_HOST}" "${GERRIT_PORTS[${GERRIT_HOST}]}" "${GERRIT_USERS[${GERRIT_HOST}]}" "${GERRIT_CHANGE_NUMBER}")"
        for CHANGE_BUG_ID in ${CHANGE_BUG_IDS}; do
            if [ "${CHANGE_BUG_ID}" == "${BUG_ID}" ]; then
                break 2
            fi
        done
        echo "*** ERROR: bug ID '${BUG_ID}' not found in commit message for CR #${GERRIT_CHANGE_NUMBER} at ${GERRIT_HOST}!"
        CHECK_REVIEWS_BUGS=false
    done
done

if ! "${CHECK_REVIEWS_BUGS}"; then
    gerrit_review --message "'* ${JOB_NAME} ${BUILD_URL} : FAILURE (no bug id)'" --verified "-1"
    exit 1
fi

gerrit_review --message "'* ${JOB_NAME} ${BUILD_URL} : STARTED using ISO=${ISO_VERSION}'"

export PATCHING_MIRRORS="${PATCHING_MIRRORS_ARRAY[*]}"
export PATCHING_MASTER_MIRRORS="${PATCHING_MASTER_MIRRORS_ARRAY[*]}"
export PATCHING_APPLY_TESTS="${WORKSPACE}/patching-tests/"
export PATCHING_BUG_ID="${BUG_ID}"

source "${VENV_PATH}/bin/activate"
if dos.py list | grep -q "${ENV_NAME}"; then
    dos.py  snapshot-list "${ENV_NAME}" | awk '/error|patching/{if(NR > 1)print $1}' | xargs -rn1 dos.py snapshot-delete "${ENV_NAME}" --snapshot-name
fi

declare -a TESTS_EXIT_CODES

sh -x "${SYSTEM_TESTS}" -V "${VENV_PATH}" -t test -e "${ENV_NAME}" -i "${ISO_PATH}" -o --group="${TEST_GROUP}" -w "${FUEL_WORKSPACE}" && TESTS_EXIT_CODE="${?}" || TESTS_EXIT_CODE="${?}"
TESTS_EXIT_CODES+=("${TESTS_EXIT_CODE}")


if eval \$${ENABLE_CUSTOM_VAR}; then
    IFS=','
    PATCHING_CUSTOM_TESTS=($CUSTOM_TESTS)
    for PATCHING_CUSTOM_TEST in ${PATCHING_CUSTOM_TESTS[@]}; do
        if [[ ${TESTS_EXIT_CODE} -ne 0 ]]; then
            break
        fi
        export PATCHING_CUSTOM_TEST
        if [[ ! -r ${ISO_PATH} ]]; then
            ISO_PATH="$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")"
        fi
        sh -x "${SYSTEM_TESTS}" -V "${VENV_PATH}" -t test -e "${ENV_NAME}" -i "${ISO_PATH}" -o --group="${TEST_GROUP}" -w "${FUEL_WORKSPACE}" && TESTS_EXIT_CODE="${?}" || TESTS_EXIT_CODE="${?}"
        TESTS_EXIT_CODES+=("${TESTS_EXIT_CODE}")
    done
fi

TESTS_EXIT_CODE=0
for EXIT_CODE in ${TESTS_EXIT_CODES[@]}; do
    let TESTS_EXIT_CODE+=${EXIT_CODE}
done

case "${TESTS_EXIT_CODE}" in
    0)   gerrit_review --message "'* ${JOB_NAME} ${BUILD_URL} : SUCCESS'" --verified "+1"; exit 0;;
    *)   gerrit_review --message "'* ${JOB_NAME} ${BUILD_URL} : FAILURE'" --verified "-1"; exit 1;;
esac
