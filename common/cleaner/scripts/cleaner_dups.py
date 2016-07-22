#!/usr/bin/env python
#
# This script is used to find ENV_PREFIX duplicates
# We cannot use the same ENV_PREFIX for different jobs in one jenkins
# this could create problem with duplicated env names in libvirt
#

import sys
from collections import defaultdict

prefixes = defaultdict(list)

with open('jobs.txt', 'r') as jobs_all:
    for job in jobs_all:
        job_name, env_prefix, last_ts_txt = job.split(' ')
        prefixes[env_prefix].append(job_name)

print
print 'Overall amount of environments {0:>3d}'.format(len(prefixes))
print '----------------------------------'
print

# searching for duplicates.
# it's bad idea to use sane env for different jobs

duplicates = {k: v for k, v in prefixes.iteritems() if len(v) > 1}

if duplicates:
    print
    print 'Found duplicated environments {0:>3d}'.format(len(duplicates))
    print '---------------------------------'
    print

    for env_prefix in sorted(duplicates):
        job_names = prefixes[env_prefix]
        print 'env prefix:   ' + env_prefix
        for job_name in job_names:
            print 'used in job:  ' + job_name
        print

# searching for envs which do not match job name.
# this will help to find possible misconfiguration before duplication occurs

non_duplicated = {k: v[0] for k, v in prefixes.iteritems() if len(v) == 1}
non_matched = {k: v for k, v in non_duplicated.iteritems() if k != v}

if non_matched:
    print
    print 'Found non-matching environments {0:>3d}'.format(len(non_matched))
    print '-----------------------------------'
    print

    for env_prefix, job_name in sorted(non_matched.iteritems()):
        print 'env prefix:   ' + env_prefix
        print 'used in job:  ' + job_name
        print

# searching for envs which have uppercase chars
# this is bad sign too..

camel_cased = {k: v for k, v in non_duplicated.iteritems() if k != k.lower()}

if camel_cased:
    print
    print 'Found camel-cased environments {0:>3d}'.format(len(camel_cased))
    print '----------------------------------'
    print

    for env_prefix, job_name in sorted(camel_cased.iteritems()):
        print 'env prefix:   ' + env_prefix
        print 'used in job:  ' + job_name
        print

if not (duplicates or non_matched or camel_cased):
    print 'No problems detected'

if duplicates:
    sys.exit(1)
