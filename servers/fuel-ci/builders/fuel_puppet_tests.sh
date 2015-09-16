#!/bin/bash
set -e
source /etc/profile
/bin/bash "${WORKSPACE}"/puppet-modules-tests/puppet-modules.sh
