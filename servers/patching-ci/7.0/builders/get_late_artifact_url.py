#!/usr/bin/env python
#-*- coding: utf-8 -*-

'''
Write file (see output_file) with url to last late_artifact

Example:
$ cat late_artifact_build_url.txt
https://patching-ci.infra.mirantis.net/view/All/job/7.0-build.late.\
    artifacts/5/artifact/artifacts/artifacts.txt
'''

import json
import logging
import os
import urllib2


late_artifact_job = "7.0-build.late.artifacts"
late_artifact_file = "artifacts.txt"

output_file = 'late_artifacts_url.txt'

syslogger = logging.getLogger('get_late_artifact_list')
loglevel = os.environ.get('LOG_LEVEL', 'INFO')
if loglevel not in ('CRITICAL', 'ERROR', 'WARNING', 'INFO', 'DEBUG'):
    loglevel = 'INFO'
logging.basicConfig(level=loglevel)


def get_full_url(*argc):
    clean = list()
    for a in argc:
        a = a.strip('/')
        clean.append(a)
    return '/'.join(clean)


def geturl(url, suffix='api/json'):
    try:
        u = urllib2.urlopen(get_full_url(url, suffix))
    except urllib2.HTTPError as e:
        raise Exception('{} {} when trying to '
                        'GET {}'.format(e.code, e.msg, e.url))
    else:
        info = u.read()

    try:
        info = json.loads(info)
    except:
        pass
    return info


jenkins_url = os.environ.get('JENKINS_URL')
if not jenkins_url:
    raise Exception("JENKINS_URL environment variable is not specified")
syslogger.debug('JENKINS_URL == {}'.format(jenkins_url))

build_url = os.environ.get('BUILD_URL')
if not build_url:
    raise Exception("BUILD_URL environment variable is not specified")
syslogger.debug('BUILD_URL == {}'.format(build_url))

workspace = os.environ.get('WORKSPACE', '.')
outf_name = '{}/{}'.format(workspace, output_file)
if os.path.isfile(outf_name):
    syslogger.debug('Removing old version of {}'.format(outf_name))
    os.remove(outf_name)

build_info = geturl(build_url)
syslogger.debug(build_info)

late_artifact_build = [_ for _ in build_info['subBuilds']
                       if _['jobName'] == late_artifact_job][0]
late_artifact_build_url = get_full_url(jenkins_url, late_artifact_build['url'])
syslogger.debug(late_artifact_build_url)
late_artifact_build_info = geturl(late_artifact_build_url)
syslogger.debug(late_artifact_build_info)

artifact_info = [_ for _ in late_artifact_build_info['artifacts']
                 if _['fileName'] == late_artifact_file][0]

artifact_url = get_full_url(late_artifact_build_url,
                            'artifact',
                            artifact_info['relativePath'])
#artifact = geturl(get_full_url(late_artifact_build_url, 'artifact'),
#                  suffix=artifact_info['relativePath'])

syslogger.info('Artifacts URL: {}'.format(artifact_url))
with open(outf_name, 'w') as outf:
    outf.write(artifact_url)
    syslogger.info('Artifact url saved to {}'.format(outf_name))
