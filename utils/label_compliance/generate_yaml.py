#!/usr/bin/env python
#
# usage example: ./generate_yaml.py ../../output/patching-ci/
# ../../output/patching-ci/ - path to generated xml configs

import os
import sys
import yaml
from lxml import etree

label_template = 'label_template.yaml'
label_file = 'labels.yaml'
job_name_field = 'job_name'
stream = open(label_template, 'r')
data = yaml.load(stream)


def show_labels(tox_output_dir):
    tox_output_dir = os.path.abspath(tox_output_dir)
    tox_output_files = os.listdir(tox_output_dir)

    for filename in tox_output_files:

        filepath = os.path.join(tox_output_dir, filename)
        doc = etree.parse(filepath)
        label = doc.find('assignedNode')

        if label is None:
            data["NO_LABEL"][job_name_field] = filename
        else:
            data[label.text][job_name_field] = filename

    with open(label_file, 'w') as yaml_file:
        yaml_file.write(yaml.dump(data, default_flow_style=False))

show_labels(sys.argv[1])
