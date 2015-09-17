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

import base64
import re


re_prj_openstack = '^openstack(?P<build>-build)?/(?P<name>.+)'
re_prj_packages = '^packages/(?P<dist>[^/]+)/(?P<package>[^/]+)'
re_br_mos_ver = '^openstack-ci/fuel-(?P<version>[0-9.]+)(?P<update>-updates)?/'
re_br_pkg_ver = '^(?P<version>[0-9.]+)$'
re_pkg_name = '^.+/(.+)$'

re_bug_topic = '^bug/(?P<bug>\d+)$'
re_bug_message = '(?i)^\w+-bug:\s*#?(?P<bug>\d+)\s*$'

GIT_DEFAULT_REFSPEC = '+refs/heads/{branch}'


def params_gerrit(item, job, params):
    # Set Gerrit parameters
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
    if item.change._data:
        params['GERRIT_CHANGE_ID'] = item.change._data['id']
        params['GERRIT_CHANGE_SUBJECT'] = item.change._data['subject']
        params['GERRIT_CHANGE_COMMIT_MESSAGE'] = base64.b64encode(
            item.change._data['commitMessage']
        )
        if 'type' in item.change._data:
            params['GERRIT_EVENT_TYPE'] = item.change._data['type']
        if 'topic' in item.change._data:
            params['GERRIT_TOPIC'] = item.change._data['topic']
            bug = re.match(re_bug_topic, item.change._data['topic'])
            if bug:
                params['LP_BUG'] = 'LP-' + str(bug.group('bug'))
        if 'currentPatchSet' in item.change._data:
            params['GERRIT_PATCHSET_REVISION'] = item.change._data[
                        'currentPatchSet']['revision']
        if 'LP_BUG' not in params:
            for l in item.change._data['commitMessage'].splitlines():
                bug = re.match(re_bug_message, l)
                if bug:
                    params['LP_BUG'] = 'LP-' + str(bug.group('bug'))


def params_mos(item, job, params):
    # MOS-specific parameters
    mos_proj = re.match(re_prj_openstack, params['ZUUL_PROJECT'])
    if mos_proj:
        params['IS_OPENSTACK'] = 'true'
        params['MOS_PROJECT'] = re.sub(r'-build(/|$)', r'\1',
                                       mos_proj.group('name'))
    else:
        params['IS_OPENSTACK'] = 'false'

    mos_ver = re.match(re_br_mos_ver, params['ZUUL_BRANCH'])
    if mos_ver:
        params['MOS_VERSION'] = str(mos_ver.group('version'))
        if mos_ver.group('update'):
            params['IS_UPDATES'] = 'true'
        else:
            params['IS_UPDATES'] = 'false'


def pkg_build(item, job, params):
    params_gerrit(item, job, params)
    params_mos(item, job, params)

    # Package jobs specific parameters

    # Branch for sources is always known
    params['SOURCE_BRANCH'] = params['ZUUL_BRANCH']

    if params['IS_OPENSTACK'] == 'true':
        # Check for dependent pair of openstack and openstack-build projects
        changes = params['ZUUL_CHANGES'].split('^')
        if len(changes) == 2:
            for change_info in changes:
                change = change_info.split(':')
                if re.match(r'^openstack/', change[0]):
                    params['SRC_PROJECT'] = change[0]
                    params['SOURCE_BRANCH'] = change[1]
                    params['SOURCE_REFSPEC'] = change[2]
                if re.match(r'^openstack-build/', change[0]):
                    params['SPEC_PROJECT'] = change[0]
                    params['SPEC_BRANCH'] = change[1]
                    params['SPEC_REFSPEC'] = change[2]
        else:
            # Guess source and build spec project names
            params['SRC_PROJECT'] = re.sub(r'-build(/|$)', r'\1',
                                           params['ZUUL_PROJECT'])
            params['SPEC_PROJECT'] = re.sub(r'(/|$)', r'-build\1',
                                            params['SRC_PROJECT'])
            # Branch for build specs matches branch of sources
            params['SPEC_BRANCH'] = params['ZUUL_BRANCH']

            # Guess for which project use given refspec
            if params['SRC_PROJECT'] == params['ZUUL_PROJECT']:
                params['SOURCE_REFSPEC'] = params['GERRIT_REFSPEC']
            else:
                params['SOURCE_REFSPEC'] = GIT_DEFAULT_REFSPEC.format(
                    branch=params['ZUUL_BRANCH']
                )

            if params['SPEC_PROJECT'] == params['ZUUL_PROJECT']:
                params['SPEC_REFSPEC'] = params['GERRIT_REFSPEC']
            else:
                params['SPEC_REFSPEC'] = GIT_DEFAULT_REFSPEC.format(
                    branch=params['ZUUL_BRANCH']
                )
    else:
        params['SRC_PROJECT'] = params['ZUUL_PROJECT']
        params['SOURCE_REFSPEC'] = params['GERRIT_REFSPEC']

    pkg_proj = re.match(re_prj_packages, params['ZUUL_PROJECT'])
    if pkg_proj:
        params['DIST'] = pkg_proj.group('dist')
        params['PACKAGENAME'] = pkg_proj.group('package')
        pkg_ver = re.match(re_br_pkg_ver, params['ZUUL_BRANCH'])
        if pkg_ver:
            params['MOS_VERSION'] = str(pkg_ver.group('version'))
    else:
        params['PACKAGENAME'] = re.match(re_pkg_name,
                                         params['SRC_PROJECT']).group(1)

    params['REQUEST_NUM'] = 'CR-' + str(params['ZUUL_CHANGE'])

    params['LAST_STAGE'] = str(item.change.is_merged).lower()
    params['TEST_INSTALL'] = str(not item.change.is_merged).lower()
    params['TEST_SYSTEST'] = ('false' if params['ZUUL_BRANCH'] == 'master' else
                              str(not item.change.is_merged).lower())

    # Temporary disable systest
    params['TEST_SYSTEST'] = 'false'


def pkg_build_debian(item, job, params):
    params_gerrit(item, job, params)
    params_mos(item, job, params)

    # Package jobs specific parameters

    # Branch for sources is always known
    params['SOURCE_BRANCH'] = params['ZUUL_BRANCH']

    if params['IS_OPENSTACK'] == 'true':
        # Check for dependent pair of openstack and openstack-build projects
        changes = params['ZUUL_CHANGES'].split('^')
        if len(changes) == 2:
            for change_info in changes:
                change = change_info.split(':')
                if re.match(r'^openstack/(?!deb-)', change[0]):
                    params['SRC_PROJECT'] = change[0]
                    params['SOURCE_BRANCH'] = change[1]
                    params['SOURCE_REFSPEC'] = change[2]
                if re.match(r'^openstack/deb-', change[0]):
                    params['SPEC_PROJECT'] = change[0]
                    params['SPEC_BRANCH'] = change[1]
                    params['SPEC_REFSPEC'] = change[2]
        else:
            # Guess source and build spec project names
            params['SRC_PROJECT'] = re.sub(r'/deb-', '/',
                                           params['ZUUL_PROJECT'])
            params['SPEC_PROJECT'] = re.sub(r'/', '/deb-',
                                            params['SRC_PROJECT'])
            # Branch for build specs matches branch of sources
            params['SPEC_BRANCH'] = params['ZUUL_BRANCH']

            # Guess for which project use given refspec
            if params['SRC_PROJECT'] == params['ZUUL_PROJECT']:
                params['SOURCE_REFSPEC'] = params['GERRIT_REFSPEC']
            else:
                params['SOURCE_REFSPEC'] = GIT_DEFAULT_REFSPEC.format(
                    branch=params['ZUUL_BRANCH']
                )

            if params['SPEC_PROJECT'] == params['ZUUL_PROJECT']:
                params['SPEC_REFSPEC'] = params['GERRIT_REFSPEC']
            else:
                params['SPEC_REFSPEC'] = GIT_DEFAULT_REFSPEC.format(
                    branch=params['ZUUL_BRANCH']
                )
    else:
        params['SRC_PROJECT'] = params['ZUUL_PROJECT']
        params['SOURCE_REFSPEC'] = params['GERRIT_REFSPEC']

    params['PACKAGENAME'] = re.match(re_pkg_name,
                                     params['SRC_PROJECT']).group(1)

    params['REQUEST_NUM'] = 'CR-' + str(params['ZUUL_CHANGE'])

    params['LAST_STAGE'] = str(item.change.is_merged).lower()
    params['TEST_INSTALL'] = str(not item.change.is_merged).lower()
    params['TEST_SYSTEST'] = ('false' if params['ZUUL_BRANCH'] == 'master' else
                              str(not item.change.is_merged).lower())

    # Temporary disable systest
    params['TEST_SYSTEST'] = 'false'
