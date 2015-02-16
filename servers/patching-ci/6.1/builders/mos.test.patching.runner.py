#!${PYTHON_VENV}/bin/python

import json
import os
import re
import yaml

import paramiko


JENKINS_PARAMETERS_FILE = "parameters.txt"
GERRIT_TOPIC = os.environ.get("GERRIT_TOPIC", None)
OPENSTACK_PROJECTS = os.environ.get("OPENSTACK_PROJECTS", None)
OPENSTACK_BRANCH = os.environ.get("OPENSTACK_BRANCH", None)
FUELINFRA_PROJECTS = os.environ.get("FUELINFRA_PROJECTS", None)
FUELINFRA_BRANCH = os.environ.get("FUELINFRA_BRANCH", None)
_GERRIT_HOSTS = os.environ.get("GERRIT_HOSTS", None)


class PatchingError(Exception):
    def __init__(self, message):
        red = '\033[1;41;33m'
        reset = '\033[0m'
        super(PatchingError, self).__init__(red + message + reset)


def exec_ssh(client, command):
    with client.get_transport().open_session() as chan:
        stdout = chan.makefile('rb')
        stderr = chan.makefile_stderr('rb')
        chan.exec_command(command)
        result = {
            'stdout': stdout.read(),
            'stderr': stderr.read(),
            'exit_code': chan.recv_exit_status()
        }
    return result


def get_gerrit_cr_by_topic(gerrit, topic, project, branch):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname=gerrit["host"],
                   port=int(gerrit["port"]),
                   username=gerrit["user"])
    result = exec_ssh(client, "gerrit query --format JSON 'topic:{0} project:"
                              "{1} branch:{2} status:open'".format(topic,
                                                                   project,
                                                                   branch))
    query_result = []
    for line in result['stdout'].strip().split('\n'):
        res = json.loads(line.strip())
        if 'number' in res.keys():
            query_result.append(res)
    client.close()
    return query_result


def get_erratum(bug_id):
    erratum = "./patching-tests/bugs/{0}/erratum.yaml".format(bug_id)
    if not os.path.exists(erratum):
        raise PatchingError('Erratum for bug #{0} not found!'.format(bug_id))
    with open(erratum) as _erratum:
        return yaml.load(_erratum)


if _GERRIT_HOSTS is None:
    raise PatchingError("No Gerrit hosts are specified!")
GERRIT_HOSTS = [{"host": h.split(':')[0], "port": h.split(':')[1],
                 "user": h.split(':')[2]} for h in _GERRIT_HOSTS.split(',')]

if GERRIT_TOPIC is None:
    raise PatchingError("No Gerrit TOPIC is specified!")
gerrit_topic_match = re.search(r'^bug/(\d+)$', GERRIT_TOPIC)
if not gerrit_topic_match:
    raise PatchingError("Gerrit TOPIC has incorrect format! "
                        "It should match pattern: '^bug/(\d+)$' !")
BUG_ID = gerrit_topic_match.group(1)

ERRATUM = get_erratum(BUG_ID)
erratum_required_keys = ['title', 'description', 'targets']
if not all(k in ERRATUM.keys() for k in erratum_required_keys):
    raise PatchingError('Erratum for bug #{0} has incorrect format! It should '
                        'contain {1} keys!'.format(BUG_ID,
                                                   erratum_required_keys))

if len(ERRATUM['targets']) == 0:
    raise PatchingError('There are no targets for patch specified!')

JENKINS_PARAMETERS = [
    'BUG_ID={0}'.format(BUG_ID)
]

REVIEWS = []

for gerrit in GERRIT_HOSTS:
    project = OPENSTACK_PROJECTS \
        if 'openstack.org' in gerrit["host"] else FUELINFRA_PROJECTS
    branch = OPENSTACK_BRANCH \
        if 'openstack.org' in gerrit["host"] else FUELINFRA_BRANCH
    code_reviews = get_gerrit_cr_by_topic(gerrit=gerrit,
                                          topic=GERRIT_TOPIC,
                                          project=project,
                                          branch=branch)

    for code_review in code_reviews:
        if not re.search('(Closes|Partial)-bug:\s+#{0}'.format(BUG_ID),
                         code_review['commitMessage'], re.IGNORECASE):
            raise PatchingError('Patch from CR {0} doesn\'t contain '
                                '"Closes-bug: #{1}" or "Partial-bug: #{1}" '
                                'in commit message'.format(code_review['url'],
                                                           BUG_ID))
        REVIEWS.append(code_review['url'])
    gerrit['numbers'] = [code_review['number'] for code_review in code_reviews]
    JENKINS_PARAMETERS.append('GERRIT_HOST{0}={1}:{2}:{3}'.format(
        GERRIT_HOSTS.index(gerrit)+1,
        gerrit['host'], gerrit['port'], gerrit['user']
    ))
    JENKINS_PARAMETERS.append('GERRIT_CHANGES_NUMBERS{0}={1}'.format(
        GERRIT_HOSTS.index(gerrit)+1, ','.join(map(str, gerrit['numbers']))))

JENKINS_PARAMETERS.append('GERRIT_HOSTS_COUNT={0}'.format(len(GERRIT_HOSTS)))

CUSTOM_TESTS = []

if 'tests' in ERRATUM.keys():
    CUSTOM_TESTS = ERRATUM['tests']

JENKINS_PARAMETERS.append('CUSTOM_TESTS={0}'.format(','.join(CUSTOM_TESTS)))

env_patching = 'false'
master_patching = 'false'

for target in ERRATUM['targets']:
    if target['type'] == 'environment':
        env_patching = 'true'
    elif target['type'] == 'master':
        master_patching = 'true'

JENKINS_PARAMETERS.append('ENABLED_RPM_PATCHING={0}'.format(env_patching))
JENKINS_PARAMETERS.append('ENABLED_DEB_PATCHING={0}'.format(env_patching))
JENKINS_PARAMETERS.append('ENABLED_CENTOS_MASTER_PATCHING={0}'.format(
    master_patching))
JENKINS_PARAMETERS.append('ENABLED_UBUNTU_MASTER_PATCHING={0}'.format(
    master_patching))

REGENERATE_PARAMETERS = [
    'regenerate_image_ubuntu',
    'regenerate_image_centos',
    'regenerate_bootstrap',
    'regenerate_containers'
]

for RP in REGENERATE_PARAMETERS:
    if RP in ERRATUM.keys():
        rp_value = str(ERRATUM[RP]).lower()
    else:
        rp_value = 'false'

    JENKINS_PARAMETERS.append('{0}={1}'.format(RP.upper(), rp_value))

with open(JENKINS_PARAMETERS_FILE, 'w') as params_file:
    params_file.write('\n'.join(JENKINS_PARAMETERS))

print "<a href='https://launchpad.net/bugs/{0}'>LP#{0}</a><br>".format(BUG_ID),
for CR in REVIEWS:
    print "[<a href='{0}'>CR#{1}</a>] ".format(CR, REVIEWS.index(CR)),
