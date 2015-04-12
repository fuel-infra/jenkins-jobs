#!/usr/bin/env python

import datetime
import json
import os
import re
import subprocess
import urllib

def url2json(url):
    """ get dictonary from url (json parser) """
    return json.loads(urllib.urlopen(url).read())

def get_environment_prefix(job_url):
    """ check environment prefix, return None if not available """
    job_data = url2json('%s/api/json' % job_url)
    for property in job_data['property']:
        if 'parameterDefinitions' in property.keys():
            for parameter in property['parameterDefinitions']:
                if parameter['defaultParameterValue']['name'] == 'ENV_PREFIX':
                    return parameter['defaultParameterValue']['value']

class Cleaner():
    def __init__(self):
        # get main view url
        jenkins_all_url = '%s/view/All/api/json' % os.environ['JENKINS_URL']

        # create dictionary (job_name -> [env_prefix, url]) of jobs
        self.jobs={}
        for job in url2json(jenkins_all_url)[u'jobs']:
            job_name = job[u'name']
            job_url = job['url']
            env_prefix = get_environment_prefix(job_url)
            # only add job if ENV_PREFIX exists in job description
            if env_prefix:
                self.jobs[str(job_name)] = [env_prefix, job_url]

        # prepare list of devops envs to iterate
        self.devops = []
        if os.environ['DEVOPS_2_9'] == 'true':
            self.devops.append('/home/jenkins/venv-nailgun-tests-2.9')
        if os.environ['DEVOPS_2_5'] == 'true':
            self.devops.append('/home/jenkins/venv-nailgun-tests')

        # get category lifetime from environment
        self.lifetimes = [('.*staging.*', int(os.environ['STAGING'])),
                     ('.*system_test.*', int(os.environ['SYSTEMTEST'])),
                     ('.*', int(os.environ['OTHER']))]

    def start(self):
        # cleaner itself
        for devops_path in self.devops:
            print 'Changing environment to: (%s)' % devops_path
            # get list of local environments
            dos_path = "%s/bin/dos.py" % devops_path
            local_environments = subprocess.check_output([dos_path, 'list', '--timestamp']).split('\n')[:-1]
            print 'Local environments found: %s' % local_environments

            for env in local_environments:
                # try to get verified data first
                try:
                    env_name, local_timestamp_text = env.split(' ')
                    local_timestamp = datetime.datetime.strptime(local_timestamp_text.split('.')[0], '%Y-%m-%d_%H:%M:%S')
                except:
                    continue
                print 'Analyzing %s environment:' % env_name
                if env_name.startswith('env_'):
                    print '- environment is env_* - skipping'
                    continue
                env_lifetime_days = self.get_job_lifetime(env_name)
                # if older then 10 days - just delete
                if (datetime.datetime.now() - local_timestamp) > datetime.timedelta(days=10):
                    print '- this build is safe to remove (%s - older then 10 days)' % local_timestamp
                    self.local_remove_env(dos_path, env_name)
                # if lifetime expired - check if ready to erase
                elif (datetime.datetime.now() - local_timestamp) > datetime.timedelta(days=env_lifetime_days):
                    print '- old enough to be analysed (%s)' % local_timestamp
                    print '- looking for a job by name (%s)' % env_name
                    server_side_job = self.server_get_job_by_name(env_name)
                    if not server_side_job:
                        print '- server job not found'
                        continue
                    print '- found job (%s)' % server_side_job
                    server_latest_ts = self.get_last_build_timestamp(server_side_job)
                    print '- local_timestamp = %s' % local_timestamp
                    print '- server_latest_ts = %s' % server_latest_ts
                    # safety delta of 5 hours
                    if (server_latest_ts - local_timestamp) > datetime.timedelta(hours=5):
                        print '- this build is safe to remove'
                        self.local_remove_env(dos_path, env_name)
                    # safety delta of 2 days (for builds created before applying new devops version)
                    elif (local_timestamp - server_latest_ts) > datetime.timedelta(days=2):
                        print '- this build is safe to remove (has wrong env date)'
                        self.local_remove_env(dos_path, env_name)
                    else:
                        print '- this build is not safe to remove (too close to the most recent build)'
                else:
                    print '- not old enough to be analysed (%s)' % local_timestamp

    def get_job_lifetime(self, env):
        """ get lifetime of a job """
        for pair in self.lifetimes:
            if re.match(pair[0], env):
                return pair[1]

    def get_last_build_timestamp(self, job_name):
        """ check latest build timestamp """
        job_data = url2json('%s/api/json' % self.jobs[job_name][1])
        last_build_url = job_data[u'lastBuild'][u'url']
        last_build_data = url2json('%s/api/json' % last_build_url)
        return datetime.datetime.fromtimestamp(last_build_data[u'timestamp']/1000)

    def server_get_job_by_name(self, env_name):
        """ get server job by local (probably suffixed) name """
        all_jobs = self.jobs.keys()
        # catch empty job list
        if not len(all_jobs):
            return None
        all_jobs.sort(key=len, reverse=True)
        for job_name in all_jobs:
            env_prefix = self.jobs[job_name][0]
            # verify first, if worth of scoring
            if env_name.startswith(env_prefix):
                return job_name

    def local_remove_env(self, dos_path, env_name):
        print 'Removing: %s' % env_name
        subprocess.check_output([dos_path, 'erase', env_name])

if __name__ == "__main__":
    cleaner = Cleaner()
    cleaner.start()

