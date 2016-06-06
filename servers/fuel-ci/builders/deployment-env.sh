#!/bin/bash
#
# ENV_NAME=env_{version-id}_{testgroup}

echo "STEP 0: check and update test environment"

set -ex

## variables
LAST_SUCCESS_DEVOPS_BUILD_URL="${JENKINS_URL}job/${ENV_JOB}/lastSuccessfulBuild"
# get last successful build number of devops.{version-id}.env job
LAST_DEVOPS_BUILD_NUMBER=$(curl -sSf "${LAST_SUCCESS_DEVOPS_BUILD_URL}/buildNumber")
# get needed ${FUEL_QA_COMMIT}
export $(curl -sSf "${LAST_SUCCESS_DEVOPS_BUILD_URL}/artifact/fuel_qa_commit.txt")
# get needed ${MAGNET_LINK}
export $(curl -sSf "${LAST_SUCCESS_DEVOPS_BUILD_URL}/artifact/magnet_link.txt")
export LAST_DEVOPS_BUILD_NUMBER
## functions
function fuel-qa_update {
  # checkout of new 'fuel-qa' version
  git -C "${SYSTEST_ROOT}" checkout "${FUEL_QA_COMMIT}"
}

function cleanup_devops_env {
  # devops env cleanup by grep {ENV_PREFIX}
  DEVOPS_ENVS=($(grep "${ENV_PREFIX}" <(dos.py list) || true ))
  for dos_env in "${DEVOPS_ENVS[@]}"; do
    dos.py erase "${dos_env}"
  done
}

function iso_update {
  # download ISO via torrents with symlink in WORKSPACE
  ISO_PATH=$(seedclient.py -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")
}

function prepare_deployment_properties {
  # pass parameters to deployment test
  cat > deployment.properties <<DEPLOYMENTPROPERTIES
ISO_PATH=${ISO_PATH}
ENV_NAME=${ENV_NAME}
DEPLOYMENTPROPERTIES
}

function get_fuel_devops_version {
  # activate venv and get fuel-devops version
  FUEL_DEVOPS_VERSION=$(dos.py version)
  export FUEL_DEVOPS_VERSION
}

# forced cleanup for 'run_on_node'
if [ "${FORCE_CLEAN}" = "true" ]
  then
    rm -rf "${SYSTEST_ROOT}"
    cleanup_devops_env
fi

# remove broken symlinks on not existing ISO files
find -L "${WORKSPACE}" -type l -delete

iso_update
source "${VENV_PATH}/bin/activate"
## checks and actions
get_fuel_devops_version

# compare existing and required versions of 'fuel-qa'
if [[ -d "${SYSTEST_ROOT}" ]];
  then
    # if 'fuel-qa' folder exists
    CURRENT_QA_COMMIT=$(git -C "${SYSTEST_ROOT}" rev-parse HEAD)
    # compare existing commit with needed
    if [[ "${CURRENT_QA_COMMIT}" != "${FUEL_QA_COMMIT}" ]]
      then
        git -C "${SYSTEST_ROOT}" pull --ff-only origin "${FUEL_QA_BRANCH##origin/}"
        fuel-qa_update
    fi
  else
    # if 'fuel-qa' folder not exists
    git clone -b "${FUEL_QA_BRANCH}" "${FUEL_QA_REPO}" "${SYSTEST_ROOT}"
    fuel-qa_update
fi

# rename with using devops job number
ENV_NAME="${ENV_PREFIX}_${LAST_DEVOPS_BUILD_NUMBER}"

# if existing env is not same as needed
if ! grep -q "${ENV_NAME}" <(dos.py list)
  then
  cleanup_devops_env
fi

prepare_deployment_properties

# exit from venv
deactivate

## setup build description
CURRENT_QA_COMMIT_SHORT=$(git -C "${SYSTEST_ROOT}" rev-parse --short HEAD)
echo "Description string:" \
  "iso: $(readlink "${ISO_PATH}" | cut -d '-' -f 2-4)<br>" \
  "fuel-qa: ${CURRENT_QA_COMMIT_SHORT}<br>" \
  "fuel-devops: ${FUEL_DEVOPS_VERSION}"
