#!/usr/bin/env python
#
# This script is used to find ENV_PREFIX duplicates
# We cannot use the same ENV_PREFIX for different jobs in one jenkins
# this could create problem with duplicated env names in libvirt
#

import os
import sys

prefixes = {}
errors = False

with open('jobs.txt', 'r') as jobs_all:
    for job in jobs_all:
        job_name, env_prefix, last_ts_txt = job.split(' ')
        # check if duplicate exists
        if env_prefix in prefixes.keys():
            print 'Duplicated ENV_PREFIX (%s) in %s!' % (env_prefix, job_name)
            print 'Already in %s\n' % prefixes[env_prefix]
            errors = True
            continue
        # append to comparition dictionary
        prefixes[env_prefix] = job_name

if errors:
    sys.exit(1)
