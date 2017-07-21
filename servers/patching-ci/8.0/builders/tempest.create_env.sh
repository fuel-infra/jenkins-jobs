#!/bin/bash

set -ex

# Input:
# MAGNET_LINK
# ENV_NAME
# UPGRADE_TARBALL_MAGNET_LINK
# {DEB,RPM}_LATEST
# UBUNTU_MIRROR_ID
# ENABLE_{PROPOSED,SECURITY,UPDATES,UPDATE_CENTOS}
# ERASE_ENV_PREFIX
# DISABLE_SSL
# FUEL_QA_VER
# FILE
# GROUP
# BONDING
# UPDATE_CENTOS
# OPENSTACK_RELEASE
# SLAVE_NODE_MEMORY

ISO_PATH=$(seedclient-wrapper -d -m "${MAGNET_LINK}" -v --force-set-symlink -o "${WORKSPACE}")

source "${VENV_PATH?}/bin/activate"

dos.py list | tail -n+3 | xargs -I {} dos.py destroy {}
if [[ -n "${ERASE_ENV_PREFIX}" ]]; then
    dos.py list | tail -n+3 | grep "${ERASE_ENV_PREFIX}" | xargs -I {} dos.py erase {}
fi

if [ -n "${FILE}" ]; then
    cat "mos-ci-deployment-scripts/jenkins-job-builder/maintenance/helpers/${FILE}" > fuelweb_test/tests/test_services.py
fi

export DEPLOYMENT_TIMEOUT=10000
export ENV_NAME
export ADMIN_NODE_MEMORY=4096
export SLAVE_NODE_CPU=3
export SLAVE_NODE_MEMORY
export DISABLE_SSL
export NOVA_QUOTAS_ENABLED=true
export KVM_USE=true
export BONDING
export OPENSTACK_RELEASE

./utils/jenkins/system_tests.sh -k -K -j fuelweb_test -t test -w "$(pwd)" -e "${ENV_NAME}" -o --group="${GROUP}" -i "${ISO_PATH}"

deactivate

