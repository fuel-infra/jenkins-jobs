#!/bin/bash
# Builder for the baremetal job. Basically it differs from the usual fuel-qa
# builder only by devops template and slaves control over IPMI.

# Global variables:
#   DEVOPS_SETTINGS_TEMPLATE - Used by fuel-devops to setup environement.
#       Can be overriden from the job parameters, if not - default one stored
#       on the jenkins slave is used
#   IPMI_USER, IPMI_PASSWORD - credentials for baremetal slaves IPMI control
#   NIC_FOR_ADMIN_BRIDGE - interface on Jenkins slave with Fuel VMs that
#       should be plugged into Admin network
#   ADMIN_VLAN - vlan dedicated for the Admin network

set -ex
set -o pipefail

GC='\e[1m\e[32m'
BC='\e[1m\e[34m'
RC='\e[1m\e[31m'
RST='\e[21m\e[0m'

dump_devops_template () {
    # Sets DEVOPS_SETTINGS_TEMPLATE to the temp file if was overriden from the
    # job parameters or uses predefined one stored on Jenkins slave if not.
    if [[ -n "${DEVOPS_SETTINGS_TEMPLATE}" && ! "${DEVOPS_SETTINGS_TEMPLATE}" = *"YOUR TEMPLATE FOR FUEL_DEVOPS IS HERE"* ]]; then
        echo -e "${GC}Using fuel-devops template from job parameters!${RST}"
        DEVOPS_TEMPLATE_FILE=$(mktemp -p "${WORKSPACE}")
        echo "${DEVOPS_SETTINGS_TEMPLATE}" > "${DEVOPS_TEMPLATE_FILE}"
        export DEVOPS_SETTINGS_TEMPLATE="${DEVOPS_TEMPLATE_FILE}"
    else
        echo -e "${BC}Using predefined fuel-devops template stored on Jenkins slave!${RST}"
        export DEVOPS_SETTINGS_TEMPLATE="/home/jenkins/devops_templates/baremetal_${BAREMETAL_ENV_NAME}.yaml"
        if [ ! -f "${DEVOPS_SETTINGS_TEMPLATE}" ]; then
            echo -e "${RC}Aborting! Template for fuel-devops not found!${RST}"
            return 1
        fi
    fi
}

destroy_bm_slaves () {
    # Shuts down all baremetal slaves from the template prior to starting the
    # test
    IPMI_HOSTS=($(awk '/^[ ]*ipmi_host:/{print $2}' "${DEVOPS_SETTINGS_TEMPLATE}"))
    for IPMI_HOST in "${IPMI_HOSTS[@]}"; do
        echo -e "${RC}Shutting down baremetal node ${IPMI_HOST}!${RST}"
        ipmitool -I lanplus -L operator -U "${IPMI_USER}" -P "${IPMI_PASSWORD}" -H "${IPMI_HOST}" power off
    done
}

ENV_NAME="baremetal_${BAREMETAL_ENV_NAME}"
VENV_PATH=${VENV_PATH:-"/home/jenkins/qa-venv-master-3.0"}

export ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

if [ -z "${ISO_PATH}" ]; then
    echo -e "${RC}ISO downloading failed!${RST}"
    exit 1
fi

dump_devops_template

source "${VENV_PATH}/bin/activate"

export BAREMETAL_ADMIN_IFACE="${NIC_FOR_ADMIN_BRIDGE}.${ADMIN_VLAN}"

export ENV_NAME
export VENV_PATH
export TASK_NAME="test"
export KEEP_AFTER="yes"

if [ "X${KEEP_BEFORE}" != "Xyes" ]; then
    destroy_bm_slaves
fi

if [[ "${fuel_qa_gerrit_commit}" != "none" ]] ; then
  for commit in ${fuel_qa_gerrit_commit} ; do
    git fetch https://review.openstack.org/openstack/fuel-qa "${commit}" && git cherry-pick FETCH_HEAD
  done
fi
