#!/usr/bin/python

import json
import os
import sys
import urllib2

GERRIT_URL = 'http://review.openstack.org'
GERRIT_PROTOCOLS = [
    'anonymous http',
]
GERRIT_COMMIT_VARS = {
    'fuelmain_gerrit_commit': 'FUELMAIN_GERRIT_COMMIT',
    'nailgun_gerrit_commit': 'NAILGUN_GERRIT_COMMIT',
    'astute_gerrit_commit': 'ASTUTE_GERRIT_COMMIT',
    'ostf_gerrit_commit': 'OSTF_GERRIT_COMMIT',
    'fuellib_gerrit_commit': 'FUELLIB_GERRIT_COMMIT',
    'python_fuelclient_gerrit_commit': 'PYTHON_FUELCLIENT_GERRIT_COMMIT',
    'fuel_agent_gerrit_commit': 'FUEL_AGENT_GERRIT_COMMIT',
    'fuel_nailgun_agent_gerrit_commit': 'FUEL_NAILGUN_AGENT_GERRIT_COMMIT',
    'createmirror_gerrit_commit': 'CREATEMIRROR_GERRIT_COMMIT',
    'fuelmenu_gerrit_commit': 'FUELMENU_GERRIT_COMMIT',
    'shotgun_gerrit_commit': 'SHOTGUN_GERRIT_COMMIT',
    'networkchecker_gerrit_commit': 'NETWORKCHECKER_GERRIT_COMMIT',
    'fuelupgrade_gerrit_commit': 'FUELUPGRADE_GERRIT_COMMIT'
}
ENVIRONMENT_FILE='${WORKSPACE}/environment'


def log(string):
    sys.stderr.write('{0}\n'.format(string))

def die(string):
    log(string)
    sys.exit(1)

def get_ref(baseurl, number):
    url = '{0}/changes/?q={1}&o=CURRENT_REVISION'.format(baseurl, number)
    log("Fetching {0} ...".format(url))
    response = urllib2.urlopen(url)
    string = ''
    for line in response.readlines()[1:]:
        string += line.strip()
    data = json.loads(string)
    current_revision = data[0].get('current_revision', None)
    if current_revision is None:
        return ''
    for protocol in GERRIT_PROTOCOLS:
        ref = data[0]['revisions'].get(current_revision, {}).get(
            'fetch', {}).get(protocol, {}).get('ref', None)
        if ref:
            log("Got {0}".format(ref))
            return ref
    return ''

def check_env_set(*args):
    for name in args:
        value = os.getenv(name, None)
        if value is None:
            die("Environment variable '{0}' is not set.".format(name))


check_env_set('WORKSPACE')
ENVIRONMENT_FILE = os.path.expandvars(ENVIRONMENT_FILE)

with open(ENVIRONMENT_FILE, 'w+') as f:
    for name in GERRIT_COMMIT_VARS:
        refs_in = os.getenv(name, 'none')
        refs_out = ''
        for ref in refs_in.split():
            if ref == 'none':
                refs_out = 'none'
                break
            elif ref.startswith('refs'):
                refs_out += '{0} '.format(ref)
            else:
                refs_out += '{0} '.format(get_ref(GERRIT_URL, ref))
        f.write('export {0}="{1}"\n'.format(GERRIT_COMMIT_VARS[name],
                                            refs_out.strip()))

