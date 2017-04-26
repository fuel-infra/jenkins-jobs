#!/usr/bin/env python
# vim: ai ts=4 sts=4 et sw=4 ft=python

#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License

# This script parses Perestroika's publisher status report found in current
# working directory, saves info about published version to JSON file if
# GERRIT_CHANGE_STATUS is 'MERGED', and in any case creates HTML report from
# above JSON file.
#
# Environment variables:
#
#   GERRIT_URL - Base Gerrit URL to create links to GitWeb
#   GERRIT_HOST - Hostname of Gerrit host used when GERRIT_URL is unset. HTTPS
#     scheme will be used for links.
#   GERRIT_CHANGE_STATUS - If not 'MERGED' then info about package will not be
#     parsed and not saved.
#   GERRIT_PROJECT - Project name for package publishing.
#
#   ZUUL_COMMIT - Used if publisher status doesn't contains Git revision.
#
#   PKG_JSON_REPORT - JSON file to save verion info.
#   PKG_HTML_REPORT - HTML report.

import itertools
import json
import os
import time


# Use GERRIT_URL as base for links or https://<GERRIT_HOST>, if GERRIT_URL
# not set. GERRIT_HOST by default is Mirantis' Gerrit.
GERRIT_URL = os.environ.get(
    'GERRIT_URL',
    'https://' + os.environ.get('GERRIT_HOST', 'review.fuel-infra.org'))

# GERRIT_URL must be terminated by slash
if (GERRIT_URL[-1:] != '/'):
    GERRIT_URL += '/'

# Perestroika's publisher status files
DEB_PUBLISHER_FILE = 'deb.publish.setenvfile'
RPM_PUBLISHER_FILE = 'rpm.publish.setenvfile'

# JSON file to store version info
JSON_REPORT = os.environ.get('PKG_JSON_REPORT', 'pkg-versions.json')
JSON_REPORT = os.path.expanduser(JSON_REPORT)
JSON_REPORT = os.path.expandvars(JSON_REPORT)

# HTML report
HTML_REPORT = os.environ.get('PKG_HTML_REPORT', 'pkg-versions.html')
HTML_REPORT = os.path.expanduser(HTML_REPORT)
HTML_REPORT = os.path.expandvars(HTML_REPORT)

# Template for HTML report
HTML_HEADER = """<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
    "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Cache-Control" content="no-cache">
<meta http-equiv="Pragma" content="no-cache">
<title>Published package versions for projects</title>
<link rel="shortcut icon" href="/favicon.gif">
<link rel="stylesheet" type="text/css"
    href="https://static.fuel-infra.org/bootstrap/3.3.4/css/bootstrap.min.css">
</head>
<body>
<table class="table table-hover table-condensed">"""

HTML_FOOTER = """</table>
</body>
</html>"""

# Use info from existing JSON file containing package versions,
# or create empty objects if file doesn't exists
if (os.path.isfile(JSON_REPORT)):
    with open(JSON_REPORT, 'r') as json_report:
        pkgs = json.load(json_report)
else:
    pkgs = {}

# Get project name
project = os.environ.get('GERRIT_PROJECT')

# Don't take into account unmerged changes
if (os.environ.get('GERRIT_CHANGE_STATUS') == 'MERGED'):

    # Prepare info about DEB package
    deb_pkg_info = {}
    deb_publishing_result = False
    deb_info_found = False
    if (os.path.isfile(DEB_PUBLISHER_FILE)):
        deb_pkg_info['project'] = project
        deb_pkg_info['timestamp'] = os.path.getmtime(DEB_PUBLISHER_FILE)
        with open(DEB_PUBLISHER_FILE, 'r') as statfile:
            for string in statfile:
                varname, varvalue = string.split('=')
                if (varname == 'DEB_PUBLISH_SUCCEEDED'):
                    deb_publishing_result = bool(varvalue.strip())
                elif (varname == 'DEB_DISTRO'):
                    deb_distro = varvalue.strip()
                    deb_info_found = True
                elif (varname == 'DEB_VERSION'):
                    deb_pkg_info['version'] = varvalue.strip()
                elif (varname == 'DEB_CHANGE_REVISION'):
                    deb_pkg_info['refsha'] = varvalue.strip() \
                        or os.environ.get('ZUUL_COMMIT')

    # Prepare info about RPM package
    rpm_pkg_info = {}
    rpm_publishing_result = False
    rpm_info_found = False
    if (os.path.isfile(RPM_PUBLISHER_FILE)):
        rpm_pkg_info['project'] = project
        rpm_pkg_info['timestamp'] = os.path.getmtime(RPM_PUBLISHER_FILE)
        with open(RPM_PUBLISHER_FILE, 'r') as statfile:
            for string in statfile:
                varname, varvalue = string.split('=')
                if (varname == 'RPM_PUBLISH_SUCCEEDED'):
                    rpm_publishing_result = bool(varvalue.strip())
                elif (varname == 'RPM_DISTRO'):
                    rpm_distro = varvalue.strip()
                    rpm_info_found = True
                elif (varname == 'RPM_VERSION'):
                    rpm_pkg_info['version'] = varvalue.strip()
                elif (varname == 'RPM_CHANGE_REVISION'):
                    rpm_pkg_info['refsha'] = varvalue.strip() \
                        or os.environ.get('ZUUL_COMMIT')

    # Update version info for just published package(s)
    # using normalized project name (for build spec projects)
    prj = project.replace('-build', '')

    if (deb_info_found and deb_publishing_result):
        pkgs.setdefault(prj, {})[deb_distro] = deb_pkg_info

    if (rpm_info_found and rpm_publishing_result):
        pkgs.setdefault(prj, {})[rpm_distro] = rpm_pkg_info

    # Save package version info
    with open(JSON_REPORT, 'w') as json_report:
        json.dump(pkgs, json_report, indent=4, sort_keys=True)

# Get a list of distributions to use later as table columns
distros = set(itertools.chain(*pkgs.values()))

# Prepare HTML templates for table rows/cells
th = '<thead><tr><th>Project</th>'
tr = '<tr><td>{project}</td>'
for distro in distros:
    tr += ('<td>'
           '<a href="' + GERRIT_URL + 'gitweb?p={' + distro + '_project}.git;'
           'a=shortlog;h={' + distro + '_refsha}">{' + distro + '_version}'
           '</a>{' + distro + '_timestamp}</td>')
    th += '<th>' + distro + '</th>'
th += '</tr></thead>'
tr += '</tr>'

# Sort package list for HTML report
packages = sorted(pkgs.keys())

# Save HTML report
with open(HTML_REPORT, 'w') as html_report:
    html_report.write(HTML_HEADER)
    html_report.write(th)
    html_report.write('<tbody>')
    for package in packages:
        info = pkgs[package]
        pkg = {'project': package}
        for distro in sorted(distros):
            info_distro = info.get(
                distro,
                {'version': '', 'project': '', 'refsha': '', 'timestamp': None}
            )
            pkg[distro + '_version'] = info_distro['version'][2:] \
                if (info_distro['version'][0:2] == '0:') \
                else info_distro['version']
            pkg[distro + '_project'] = info_distro['project']
            pkg[distro + '_refsha'] = info_distro['refsha']
            ts = info_distro.get('timestamp')
            if (ts):
                pkg[distro + '_timestamp'] = time.strftime(
                    ' (%Y-%m-%d %H:%M:%S UTC)', time.gmtime(ts))
            else:
                pkg[distro + '_timestamp'] = ''
        html_report.write(tr.format(**pkg))
    html_report.write('</tbody>')
    html_report.write(HTML_FOOTER)
