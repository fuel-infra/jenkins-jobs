# Copyright 2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import re


re_proj_openstack = r'^openstack(?P<build>-build)?/(?P<name>.+)'
re_branch_mos_version = r'^openstack-ci/fuel-(?P<version>[0-9.]+)(?P<update>-updates)?/'


def params_gerrit(item, job, params):
    # Gerrit parameters
    params['GERRIT_PROJECT'] = params['ZUUL_PROJECT']
    params['GERRIT_BRANCH'] = params['ZUUL_BRANCH']
    params['GERRIT_CHANGE_NUMBER'] = params['ZUUL_CHANGE']
    params['GERRIT_CHANGE_STATUS'] = item.change.status
    params['GERRIT_CHANGE_URL'] = item.change.url
    params['GERRIT_PATCHSET_NUMBER'] = item.change.patchset
    params['GERRIT_REFSPEC'] = item.change.refspec
    if hasattr(item.change, 'owner'):
        params['GERRIT_CHANGE_OWNER'] = '"{name}" <{email}>'.format(
            name=item.change.owner['name'],
            email=item.change.owner['email']
        )
        params['GERRIT_CHANGE_OWNER_NAME'] = item.change.owner['name']
        params['GERRIT_CHANGE_OWNER_EMAIL'] = item.change.owner['email']


def params_mos(item, job, params):
    # MOS-specific parameters
    mos_proj = re.match(re_proj_openstack, params['ZUUL_PROJECT'])
    if mos_proj:
        params['IS_OPENSTACK'] = 'true'
        params['MOS_PROJECT'] = re.sub(r'-build(/|$)', r'\1', mos_proj.group('name'))
    else:
        params['IS_OPENSTACK'] = 'false'

    mos_ver = re.match(re_branch_mos_version, params['ZUUL_BRANCH'])
    if mos_ver:
        params['MOS_VERSION'] = str(mos_ver.group('version'))
        if mos_ver.group('update'):
            params['IS_UPDATES'] = 'true'
        else:
            params['IS_UPDATES'] = 'false'


def pkg_build(item, job, params):
    # Common params
    params_gerrit(item, job, params)
    params_mos(item, job, params)

    # Package jobs specific parameters
    if params['IS_OPENSTACK'] == 'true':
        params['SRC_PROJECT'] = re.sub(r'-build(/|$)', r'\1', params['ZUUL_PROJECT'])
        params['SPEC_PROJECT'] = re.sub(r'(/|$)', r'-build\1', params['ZUUL_PROJECT'])
        params['SPEC_BRANCH'] = params['ZUUL_BRANCH']
        if params['SRC_PROJECT'] == params['ZUUL_PROJECT']:
            params['SOURCE_REFSPEC'] = params['GERRIT_REFSPEC']
        if params['SPEC_PROJECT'] == params['ZUUL_PROJECT']:
            params['SPEC_REFSPEC'] = params['GERRIT_REFSPEC']
        params['COMPONENT_PATH'] = 'cluster/'
    else:
        params['SRC_PROJECT'] = params['ZUUL_PROJECT']
        params['COMPONENT_PATH'] = 'fuel/'

    if params['SRC_PROJECT'] == params['ZUUL_PROJECT']:
        params['SOURCE_REFSPEC'] = params['GERRIT_REFSPEC']

    params['SOURCE_BRANCH'] = params['ZUUL_BRANCH']

    params['LAST_STAGE'] = str(item.change.is_merged).lower()

    if not item.change.is_merged:
        params['TEST_INSTALL'] = 'true'
    else:
        params['TEST_INSTALL'] = 'false'
