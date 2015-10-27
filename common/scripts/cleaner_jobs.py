#!/usr/bin/env python

import json
import os
import urllib

parameters_url = '%s/view/All/api/json?depth=1&pretty=true&&tree=jobs[name,lastBuild[number,duration,timestamp,result],actions[parameterDefinitions[name,defaultParameterValue[*]]]]' % os.environ['JENKINS_URL']
json_parameters = json.loads(urllib.urlopen(parameters_url).read())

output_file = open('jobs.txt', 'w')

def get_env_prefixed(job):
    for action in job['actions']:
        if action and 'parameterDefinitions' in action.keys():
            for parameter in action['parameterDefinitions']:
                if parameter['name'] == 'ENV_PREFIX':
                    return parameter['defaultParameterValue']['value']
    return False

for job in json_parameters['jobs']:
    job_prefix = get_env_prefixed(job)
    if job_prefix:
        # get job name
        name = job['name']
        # get last build timestamp
        if job['lastBuild']:
            last_build = job['lastBuild']['timestamp']
        else:
            last_build = None
        output_file.write("%s %s %s\n" % (name, job_prefix, last_build))

output_file.close()
