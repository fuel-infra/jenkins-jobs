#!/usr/bin/env python
import argparse
import ConfigParser
import jenkins
import yaml

parser = argparse.ArgumentParser()
parser.add_argument("-c", "--conf", required=True,
                    help="Path to jenkins-job-builder config file")
parser.add_argument("-o", "--output", required=True,
                    help="Path to output YAML file")
args = parser.parse_args()

config = ConfigParser.RawConfigParser()
config.read(args.conf)

jenkinsurl = config.get('jenkins', 'url')
username = config.get('jenkins', 'user')
password = config.get('jenkins', 'password')

j = jenkins.Jenkins(jenkinsurl, username, password)
data = j.get_plugins_info(depth=2)
yaml.safe_dump(data, file(args.output,'w'), encoding='utf-8',
               allow_unicode=True)
