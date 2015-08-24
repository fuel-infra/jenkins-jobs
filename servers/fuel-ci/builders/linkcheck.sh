#!/bin/bash

set -ex

WS=${WORKSPACE}

virtualenv _requirenv
source _requirenv/bin/activate
pip install -r "${REQUIREMENTS}"

cd "${MAKEDIR}"

(make linkcheck || true) | tee "${WS}/make_output_current.txt"

egrep 'http.*:' "${WS}/make_output_current.txt" |\
  sed 's/\s\s*/ /g' | egrep -w -v "${REGEX}" | sort > "${WS}/build_current.txt"

git checkout HEAD~1

(make linkcheck || true) | tee "${WS}/make_output_previous.txt"

egrep 'http.*:' "${WS}/make_output_previous.txt" |\
  sed 's/\s\s*/ /g' | egrep -w -v "${REGEX}" | sort > "${WS}/build_previous.txt"

(diff --unchanged-line-format= --old-line-format= --new-line-format='%L' \
  "${WS}/build_previous.txt" "${WS}/build_current.txt" || true) \
  > "${WS}/build_new.txt"

if [ -s "${WS}/build_new.txt" ]
then
  exit 1
fi
