#!/usr/bin/env python
#
# usage example: ./parse_yaml.py docker-builder
# docker-builder - name of the label

import yaml
import sys

conf_file = "labels.yaml"

with open(conf_file, 'r') as config:

    doc = yaml.load(config)
    job = doc[sys.argv[1]]["verify_tests"]

    print "TRIGGERED_JOB_NAMES="+(job["name"])

    if job.has_key('params'):

        params = job["params"]

        for param, param_data in params.items():
            print '%s=%s' % (param, param_data)
