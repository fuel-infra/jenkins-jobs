#!/usr/bin/env python

import datetime
import json
import os
import subprocess
import urllib

# get main view url
jenkins_all_url = '%s/view/All/api/json' % os.environ['JENKINS_URL']

# prepare list of devops envs to iterate
devops = []
if os.environ['DEVOPS_2_9'] == 'true':
    devops.append('/home/jenkins/venv-nailgun-tests-2.9')
if os.environ['DEVOPS_2_5'] == 'true':
    devops.append('/home/jenkins/venv-nailgun-tests')

# get category lifetime from environment
lifetimes = {'staging.': int(os.environ['STAGING']),
             'system_test.': int(os.environ['SYSTEMTEST']),
             '': int(os.environ['OTHER'])}

# get lifetime of a job
def get_lifetime(env):
    for name_part in lifetimes.keys():
        if name_part in env:
            return lifetimes[name_part]

# get dictonary from url (json parser)
def url2json(url):
    return json.loads(urllib.urlopen(url).read())

# get server job by local (probably suffixed) name
def server_get_job_by_name(jobs, name):
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

# check latest build timestamp
def last_build_timestamp(jobs, job_name):
    job_data = url2json('%s/api/json' % jobs[job_name])
    last_build_url = job_data[u'lastBuild'][u'url']
    last_build_data = url2json('%s/api/json' % last_build_url)
    return datetime.datetime.fromtimestamp(last_build_data[u'timestamp']/1000)

# remove environment
def local_remove_env(dos_path, env_name):
    print 'Removing: %s' % env_name
    subprocess.check_output([dos_path, 'erase', env_name])

# cleaner itself
for devops_path in devops:
    print 'Changing environment to: (%s)' % devops_path

    # get list of local environments
    dos_path = "%s/bin/dos.py" % devops_path
    local_environments = subprocess.check_output([dos_path, 'list', '--timestamp']).split('\n')[:-1]

    # fetch dictionary (name -> url) of jobs
    jobs={}
    for job in url2json(jenkins_all_url)[u'jobs']:
        jobs[str(job[u'name'])] = job[u'url']

    print 'Local environments found: %s' % local_environments

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
        # if older then 10 days - just delete
        if (datetime.datetime.now() - local_timestamp) > datetime.timedelta(days=10):
            print '- this build is safe to remove (%s - older then 10 days)' % local_timestamp
            local_remove_env(dos_path, env_name)
        # if lifetime expired - check if ready to erase
        elif (datetime.datetime.now() - local_timestamp) > datetime.timedelta(days=env_lifetime_days):
            print '- old enough to be analysed (%s)' % local_timestamp
            print '- looking for a job by name (%s)' % env_name
            server_side_job = server_get_job_by_name(jobs, env_name)
            if not server_side_job:
                print '- server job not found'
                continue
            print '- found job (%s)' % server_side_job
            server_latest_ts = last_build_timestamp(jobs, server_side_job)
            print '- local_timestamp = %s' % local_timestamp
            print '- server_latest_ts = %s' % server_latest_ts
            # safety delta of 5 hours
            if (server_latest_ts - local_timestamp) > datetime.timedelta(hours=5):
                print '- this build is safe to remove'
                local_remove_env(dos_path, env_name)
            # safety delta of 2 days (for builds created before applying new devops version)
            elif (local_timestamp - server_latest_ts) > datetime.timedelta(days=2):
                print '- this build is safe to remove (has wrong env date)'
                local_remove_env(dos_path, env_name)
            else:
                print '- this build is not safe to remove (too close to the most recent build)'
        else:
            print '- not old enough to be analysed (%s)' % local_timestamp
