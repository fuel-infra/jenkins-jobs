#!/usr/bin/env python

import datetime
import json
import os
import subprocess
import urllib

# get main view url
jenkins_all_url = '%s/view/All/api/json' % os.environ['JENKINS_URL']

# get list of local environments
dos_path = "%s/bin/dos.py" % os.environ['VENV']
local_environments = subprocess.check_output([dos_path, 'list', '--timestamp']).split('\n')

# get category lifetime from environment
lifetimes = {'staging.': int(os.environ['STAGING']),
             'system_test.': int(os.environ['SYSTEMTEST']),
             '': int(os.environ['OTHER'])}

# get dictonary from url (json parser)
def url2json(url):
    return json.loads(urllib.urlopen(url).read())

# fetch dictionary (name -> url) of jobs
jobs={}
for job in url2json(jenkins_all_url)[u'jobs']:
    jobs[str(job[u'name'])] = job[u'url']

# get lifetime of a job
def get_lifetime(env):
    for name_part in lifetimes.keys():
        if name_part in env:
            return lifetimes[name_part]

# get server job by local (probably suffixed) name
def server_get_job_by_name(name):
    best_chars_left = 1000
    for job_name in jobs.keys():
        # verify first, if worth of scoring
        if job_name in name:
            current_chars_left = len(name.split(job_name)[1])
            if current_chars_left < best_chars_left:
                best_match = job_name
                best_chars_left = current_chars_left
    # if job was not found for some reason, return None
    if best_chars_left == 1000:
        return None
    # return matching job
    return best_match

# remove environment
def local_remove_env(env_name):
    subprocess.check_output([dos_path, 'erase', env_name])

# check latest build timestamp
def last_build_timestamp(job_name):
    job_data = url2json('%s/api/json' % jobs[job_name])
    last_build_url = job_data[u'lastBuild'][u'url']
    last_build_data = url2json('%s/api/json' % last_build_url)
    return datetime.datetime.fromtimestamp(last_build_data[u'timestamp']/1000)

# cleaner itself
print local_environments
for env in local_environments:
    # try to get verified data first
    try:
        env_name = env.split(' ')[0]
        local_timestamp_text = env.split(' ')[1]
        local_timestamp = datetime.datetime.strptime(local_timestamp_text.split('.')[0], '%Y-%m-%d_%H:%M:%S')
    except:
        continue
    print 'Analyzing %s environment:' % env_name
    if env_name.startswith('env_'):
        print '- environment is env_* - skipping'
        continue
    env_lifetime_days = get_lifetime(env_name)
    # if lifetime expired - check if ready to erase
    if (datetime.datetime.now() - local_timestamp) > datetime.timedelta(days=env_lifetime_days):
        print '- old enough to be analysed (%s)' % local_timestamp
        print '- looking for a job by name (%s)' % env_name
        server_side_job = server_get_job_by_name(env_name)
        if not server_side_job:
            print '- server job not found'
            continue
        print '- found job (%s)' % server_side_job
        server_latest_ts = last_build_timestamp(server_side_job)
        print '- local_timestamp = %s' % local_timestamp
        print '- server_latest_ts = %s' % server_latest_ts
        # safety delta of 5 hours
        if (server_latest_ts - local_timestamp) > datetime.timedelta(hours=5):
            print '- this build is safe to remove'
            local_remove_env(env_name)
        else:
            print '- this build is not safe to remove (too close to the most recent build)'
    else:
        print '- not old enough to be analysed (%s)' % local_timestamp
