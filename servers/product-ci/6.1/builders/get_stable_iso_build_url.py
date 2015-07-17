#!/usr/bin/env python
#-*- coding: utf-8 -*-

'''
Write file (see output_file) with url to last stable ISO build
(ISO that passed iso_testing_job)

Example:
$ cat stable_iso_build_url.txt
http://jenkins-product.srt.mirantis.net:8080/job/6.1.all/437/
'''

import json
import logging
import os
import urllib2


iso_testing_job = "6.1.test_all"
output_file = 'stable_iso_build_url.txt'


syslogger = logging.getLogger('stable_iso')
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

workspace = os.environ.get('WORKSPACE', '.')
outf_name = '{}/{}'.format(workspace, output_file)
if os.path.isfile(outf_name):
    syslogger.debug('Removing old version of {} before detection of '
                    'last stable ISO.'.format(outf_name))
    os.remove(outf_name)

iso_testing_job_url = get_full_url(jenkins_url, "job", iso_testing_job)
syslogger.info('Jenkins job that tests ISO is {}'
               ''.format(iso_testing_job_url))
job_info = geturl(iso_testing_job_url)
syslogger.debug(job_info)

last_success_id = 0
for build in job_info.get('builds'):
    build_info = geturl(build['url'])
    if build_info.get('result') == 'SUCCESS':
        iso_build_url = geturl(build['url'], 'artifact/iso_build_url.txt')
        iso_build_url = iso_build_url.split('=')[-1].strip()
        iso_build_info = geturl(iso_build_url)
        if iso_build_info.get('number') > last_success_id:
            last_success_id = iso_build_info['number']
            last_success = iso_build_info['url']
syslogger.info('Last successful build == {}'.format(last_success))
with open(outf_name, 'w') as outf:
    print >>outf, last_success
    syslogger.info('Saved to {}'.format(outf_name))
