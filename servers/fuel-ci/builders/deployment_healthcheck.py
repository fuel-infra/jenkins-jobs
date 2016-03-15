#!/usr/bin/env python

import json
import os
import sys
import urllib
from collections import defaultdict
from xml.etree import cElementTree as ET

def write_to_file(file, content):
    output_file = open(file, 'w')
    output_file.write('%s' % content)
    output_file.close()

def form_html(list):
    output_html = '<body><table>'
    for build in list:
        job_name = build['fullDisplayName'].split()[0]
        output_html += '<tr><td><a href=%s>%s</a></td></tr>' % \
            (build['url'], job_name)
    output_html += '</table><body>'
    return output_html

def status_html(list):
    output_html = '<body><table>'
    output_html += '<tr><td>Name</td><td>ISO version</td><td>Result</td></tr>'
    for build in list:
        job_name = build['fullDisplayName'].split()[0]
        url = build['url']
        result = build.get('result')
        description = build.get('description')
        output_html += '<tr><td><a href=%s>%s</a></td><td>%s</td><td>%s</td></tr>' % \
            (url, job_name, description, result)
    output_html += '</table></body>'
    return output_html

# http://stackoverflow.com/questions/7684333 by K3---rnc
def etree_to_dict(t):
    d = {t.tag: {} if t.attrib else None}
    children = list(t)
    if children:
        dd = defaultdict(list)
        for dc in map(etree_to_dict, children):
            for k, v in dc.iteritems():
                dd[k].append(v)
        d = {t.tag: {k:v[0] if len(v) == 1 else v for k, v in dd.iteritems()}}
    if t.attrib:
        d[t.tag].update(('@' + k, v) for k, v in t.attrib.iteritems())
    if t.text:
        text = t.text.strip()
        if children or t.attrib:
            if text:
              d[t.tag]['#text'] = text
        else:
            d[t.tag] = text
    return d

jenkins_url = os.environ['JENKINS_URL']
parameters_url = '%sview/deployment tests/api/xml?depth=2&xpath=/listView/job' \
                    '[./buildable="true"]/build[./action/parameter' \
                    '[./name="GERRIT_REFSPEC"]/value="refs/heads/master"]' \
                    '[1]&wrapper=root' % jenkins_url

xml_data = ET.fromstring(urllib.urlopen(parameters_url).read())
root = etree_to_dict(xml_data)
builds = root['root']['build']

print 'DEBUG START\n%s\nDEBUG END' % builds

# prepare discovery output
discovery = {"data": []}
for build in builds:
    job_name = build['fullDisplayName'].split()[0]
    url = build['url']
    description = build.get('description')
    discovery["data"].append({"{#JOBNAME}": job_name, "{#JOBURL}": url, "{#DESCRIPTION}": description})
json_discovery = json.dumps(discovery)
write_to_file('raw-discovery', json_discovery)

# prepare status files
raw_status = ''
failed_builds = []
for build in builds:
    job_name = build['fullDisplayName'].split()[0]
    result = build.get('result', 'SUCCESS')
    url = build['url']
    description = build.get('description')
    raw_status += '%s\t%s\t%s\t%s\n' % (job_name, result, url, description)
    if result == 'FAILURE':
        failed_builds.append(build)
write_to_file('raw-status', raw_status)
write_to_file('status.html', status_html(builds))
write_to_file('failed.html', form_html(failed_builds))

if failed_builds:
    sys.exit(1)
