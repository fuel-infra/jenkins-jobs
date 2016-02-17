#!/bin/bash
#
#  :mod:`define-timestamp` -- Set proper for updates repository
#  ============================================================
#
#  .. module:: define-timestamp
#      :platform: Ubuntu 14.04
#      :synopsis: set updates repo timestamp
#  .. versionadded:: MOS-6.1 patching
#  .. versionchanged:: MOS-8.0 patching
#  .. author:: Maksim Rasskazov <mrasskazov@mirantis.com>
#
#  .. envvar::
#      :var  DISTRO: distributive name
#      :type DISTRO: str
#
#  .. affects::
#      :file timestamp.txt: generated timestamp of updates repo
#

set -ex

TIMESTAMP_ARTIFACT="${WORKSPACE}/timestamp.txt"
rm -f "$TIMESTAMP_ARTIFACT"


TIMESTAMP_REGEXP='[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}'

if [ -z "${TIMESTAMP}" ]; then
   TIMESTAMP=$(date --utc "+%Y-%m-%d-%H%M%S")
   export TIMESTAMP
else
    # check that TIMESTAMP variable matches regexp
    echo "${TIMESTAMP}" | grep -E "^${TIMESTAMP_REGEXP}$"
fi

echo "${TIMESTAMP}" > "${TIMESTAMP_ARTIFACT}"
