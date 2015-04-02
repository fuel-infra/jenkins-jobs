#!/bin/bash

set -ex

if echo "${GERRIT_CHANGE_COMMIT_MESSAGE}" | grep -q -i "TestImpact"; then
  echo "Warning: TestImpact found in commit message"
  echo "Sending email to QA team"
  exit -1
fi
