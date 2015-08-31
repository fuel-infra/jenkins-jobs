#!/usr/bin/env python

import os
import sys

prefixes = {}
errors = False

for job_definition in open('jobs.txt', 'r').readlines():
    job_name, env_prefix, last_ts_txt = job_definition.split(' ')
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
