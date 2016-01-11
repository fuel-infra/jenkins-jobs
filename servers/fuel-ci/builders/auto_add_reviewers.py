#!/usr/bin/env python

import os
import re
import yaml
import logging
import subprocess

logging.basicConfig(format='%(asctime)-15s %(levelname)s %(message)s')
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def load_maintainers(filename):
    resp = {}
    if os.path.exists(filename):
        # # MAINTAINERS file format:
        # - path/
        #   - name: Name Surname
        #     email: mail@example.com
        try:
            with open(filename, 'r') as f:
                data = yaml.safe_load(f)
            for dirname in data.get('maintainers', []):
                resp[dirname.keys()[0].rstrip('/')] = [
                    maintainer['email'] for maintainer in dirname.values()[0]
                ]
        except yaml.parser.ParserError:
            logger.error("File '%s' parsing error", filename)
    return resp


def main():
    workspace = os.environ.get('WORKSPACE', os.path.dirname('.'))
    maintainers_filename = os.path.join(workspace, 'MAINTAINERS')

    # Prepare dict of maintainers
    maintainers = load_maintainers(maintainers_filename)
    if not maintainers:
        return

    output = subprocess.check_output(
        ['git', 'diff', '--name-only', 'HEAD^'],
    )

    # Create list of changed files
    changed_files = output.rstrip().splitlines()

    # create set with reviewers
    reviewers = set(maintainers.get('.', []))

    # Parse MAINTAINERS file in source root
    for changed_file in changed_files:
        while changed_file:
            logger.debug(changed_file)
            if changed_file in maintainers:
                for maintainer in maintainers[changed_file]:
                    reviewers.add(maintainer)
                break
            changed_file = os.path.dirname(changed_file)

    if not reviewers:
        logger.info('No reviewers found')
        return

    maintainers_list = ["--add {}".format(person) for person in reviewers]

    command = (
        "ssh -p{GERRIT_PORT} {username}@{GERRIT_HOST} gerrit set-reviewers "
        "{reviewers} {GERRIT_CHANGE_NUMBER}".format(
            username='fuel-ci',
            reviewers=' '.join(maintainers_list),
            GERRIT_PORT=os.environ.get('GERRIT_PORT', '29418'),
            GERRIT_HOST=os.environ.get('GERRIT_HOST', ''),
            GERRIT_CHANGE_NUMBER=os.environ.get('GERRIT_CHANGE_NUMBER', ''),

        )
    )

    logger.info("Running: '%s'", command)
    exit_code = subprocess.call(command.split(' '))
    if exit_code != 0:
        exit(exit_code)

if __name__ == '__main__':
    main()
