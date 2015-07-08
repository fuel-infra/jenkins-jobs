#!/bin/bash

set -x

RET_CODE="0"

while read -r file; do
  TEST_FNAME=$(basename "${file}")
  echo "Executing ${TEST_FNAME} test file"
  bats --tap "${file}"
  # if at least one test failed in at least one *.bats file,
  # then the whole job's build should be marked as failed
  if [[ "$(echo ${?})" -ne 0 ]]; then
    RET_CODE="1"
  fi
done < <(find "${WORKSPACE}" -name "*.bats" -type f)

exit "${RET_CODE}"
