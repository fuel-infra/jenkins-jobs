#!/bin/bash
set -e
source /etc/profile
/bin/bash "${WORKSPACE}/utils/jenkins/fuel_noop_tests.sh"
# archive coverage data
if [ -d "${WORKSPACE}/tests/noop/coverage" ]; then
  tar -cvJ -C "${WORKSPACE}/tests/noop" -f "${WORKSPACE}/coverage_reports.tar.xz" coverage
fi
