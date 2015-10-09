#!/bin/bash
set -ex
source /etc/profile
/bin/bash "${WORKSPACE}/utils/jenkins/fuel_validate_puppetfile.sh"
