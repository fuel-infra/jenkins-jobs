#!/usr/bin/env python

import datetime
import os
import re
import subprocess

class Cleaner():
    def __init__(self):
        # create dictionary ([env_prefix, last_timestamp]) of prefixes
        self.prefixes={}
        for job_definition in open('jobs.txt', 'r').readlines():
            job_name, env_prefix, last_ts_txt = job_definition.split(' ')
            # strip new line
            last_ts_txt = last_ts_txt.strip()
            # catch never run jobs
            if last_ts_txt == 'None':
                continue
            last_ts = datetime.datetime.fromtimestamp(float(last_ts_txt)/1000)
            self.prefixes[env_prefix] = {'job_name': job_name,
                                       'last_timestamp': last_ts,}

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
            # workaround if header added
            if local_environments and local_environments[0].startswith('NAME'):
                local_environments=local_environments[2:]

            print 'Local environments found: %s' % local_environments

            for env in local_environments:
                # try to get verified data first
                try:
                    env_name, local_timestamp_text = env.split()
                    local_timestamp = datetime.datetime.strptime(local_timestamp_text.split('.')[0], '%Y-%m-%d_%H:%M:%S')
                except:
                    continue
                print 'Analyzing %s environment:' % env_name
                if env_name.startswith('env_'):
                    print '- environment is env_* - skipping'
                    continue
                env_lifetime_hours = self.get_job_lifetime(env_name)
                # if older then 5 days - just delete
                if (datetime.datetime.now() - local_timestamp) > datetime.timedelta(days=5):
                    print '- this build is safe to remove (%s - older then 5 days)' % local_timestamp
                    self.local_remove_env(dos_path, env_name)
                # if lifetime expired - check if ready to erase
                elif (datetime.datetime.now() - local_timestamp) > datetime.timedelta(hours=env_lifetime_hours):
                    print '- old enough to be analysed (%s)' % local_timestamp
                    print '- looking for a prefix by name (%s)' % env_name
                    env_prefix = self.get_prefix_by_env_name(env_name)
                    if not env_prefix:
                        print '- server job not found'
                        continue
                    print '- found owner job (%s)' % self.prefixes[env_prefix]['job_name']
                    server_latest_ts = self.prefixes[env_prefix]['last_timestamp']
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

    def get_prefix_by_env_name(self, env_name):
        """ get server job by local (probably suffixed) name """
        all_prefixes = self.prefixes.keys()
        # catch empty job list
        if not len(all_prefixes):
            return None
        all_prefixes.sort(key=len, reverse=True)
        for env_prefix in all_prefixes:
            if env_name.startswith(env_prefix):
                return env_prefix

    def local_remove_env(self, dos_path, env_name):
        print 'Removing: %s' % env_name
        subprocess.check_output([dos_path, 'erase', env_name])

if __name__ == "__main__":
    cleaner = Cleaner()
    cleaner.start()

