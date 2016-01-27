#!/bin/bash

#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


set -ex

VENV=${WORKSPACE}_VENV
rm -Rf "${VENV}"
virtualenv -p python2.7 "${VENV}"
${VENV}/bin/pip install --upgrade tox\>=2.3.1

source "${VENV}/bin/activate"

export TEST_NAILGUN_DB=nailgun
export FUEL_WEB_ROOT="${WORKSPACE}/fuel-web"

function cleanup {
    trap - SIGINT SIGTERM
    pkill -TERM -s ${TOX_PID}
    tox -e cleanup
    exit 1
}

trap "cleanup" SIGINT SIGTERM
# Bash ignores signals when running foreground process
setsid tox -e functional,cleanup &
TOX_PID=$!
wait ${TOX_PID}
trap - SIGINT SIGTERM

deactivate
