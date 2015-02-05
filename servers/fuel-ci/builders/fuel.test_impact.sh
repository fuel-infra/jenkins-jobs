#!/bin/bash

set -ex

echo "${GERRIT_CHANGE_COMMIT_MESSAGE}" | base64 -d > gerrit_commit_message.txt 2>/dev/null || true

if grep -q -i "TestImpact" gerrit_commit_message.txt; then
  echo "Warning: TestImpact found in commit message"
  echo "Sending email to QA team"
  exit -1
fi
