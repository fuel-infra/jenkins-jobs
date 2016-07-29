#!/bin/bash

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

VENV="${WORKSPACE}_VENV"

rm -rf "${VENV}"
virtualenv -p python2.7 "${VENV}"
source "${VENV}/bin/activate"

NAILGUN="${WORKSPACE}/fuel-web/nailgun"
EXTENSION="${WORKSPACE}/fuel-nailgun-extension-cluster-upgrade"

pip install -e "$NAILGUN"
pip install -e "$EXTENSION"
pip install -r "${NAILGUN}/test-requirements.txt"
pip install -r "${EXTENSION}/test-requirements.txt"

cd "$EXTENSION"

export NAILGUN_CONFIG="${EXTENSION}/jenkins-test-settings.yaml"
sed s/openstack_citest/nailgun/g "${EXTENSION}/nailgun-test-settings.yaml" > "$NAILGUN_CONFIG"

py.test -v

deactivate
