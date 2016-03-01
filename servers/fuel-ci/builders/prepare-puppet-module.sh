#!/bin/bash
set -ex

if [ -n "${GERRIT_PROJECT}" ]; then
  module=$(echo "${GERRIT_PROJECT}"|cut -d- -f 2)
  mv "${WORKSPACE}/upstream_module/${GERRIT_PROJECT}" "${WORKSPACE}/deployment/puppet/${module}"
fi
