#!/usr/bin/env python

"""
Those tests checks the following requirements for the `projects.yaml` file:
    - Its syntax is valid
    - Each project definition should consist of the following mandatory parts:
        * project
        * description
      and could contain the following optional parts:
        * acl-config
        * upstream
      No other parts are possible.
    - All the projects listed in the `projects.yaml`` file
      must be sorted alphabetically.
"""

import logging
import os
import re
import yaml


# Only of lower case letters (a-z), digits (0-9), plus (+) and minus (-)
# and periods (.).
# They must be at least two characters long and must start with an
# alphanumeric character.
# https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Source
# Actually we can't use those restictions at least now, because many projects
# just do not follow them, for example: python-pyasn1_modules,
# python-WSGIProxy2, SDL2...
# By this reason we have whitelisted all the current ones in the
# REPOSITORIES_WHITELIST variable, but forbided to create new invalid records.
_PREFIX_PATTERN = '\A([a-z]([a-z]|\d|-)+/)*'
_DEBIAN_NAMES_PATTERN = '([a-z]|\d)([a-z]|\d|[+-.])+\Z'
PROJECT_NAMES_REGEX = re.compile(_PREFIX_PATTERN + _DEBIAN_NAMES_PATTERN)

VALID_PROJECT_PARTS = {'project', 'description', 'acl-config', 'upstream'}


def check_syntax(file_path):
    try:
        yaml.safe_load(open(file_path))
    except yaml.YAMLError as exc:
        logging.error('The file %s could not be parsed: %s', file_path, exc)
        exit(1)


def check_projects_names(file_path):
    project_regex = re.compile('.*project: (.*)\n')
    projects_items_list = yaml.safe_load(open(file_path))
    projects_names = [item['project'] for item in projects_items_list]
    sorted_names = sorted(projects_names)
    line_number, index, valid = 1, 0, True

    with open(file_path) as f:
        for line in f:
            name = project_regex.search(line)

            if name:
                name = name.groups()[0]
                if name != sorted_names[index]:
                    valid = False
                    logging.error(
                        'Project %s in file %s:%s is not '
                        'alphabetically sorted.',
                        name,
                        file_path,
                        line_number)

                if not _is_valid_project_name(name, file_path, line_number):
                    valid = False

                if projects_names.count(name) > 1:
                    valid = False
                    logging.error(
                        'Project %s in file %s:%s is duplicated.',
                         name,
                         file_path,
                         line_number)
                index += 1

            line_number += 1

    if not valid:
        exit(1)


def check_projects_sections(file_path):
    projects_items_list = yaml.safe_load(open(file_path))
    valid = True

    for item in projects_items_list:
        keys = item.keys()
        size = len(keys)

        if 'project' not in keys:
            logging.error(
                'Project %s in file %s has missed project section',
                item,
                file_path)
            valid = False

        if 'description' not in keys:
            logging.error(
                'Project %s in file %s has missed description section',
                item,
                file_path)
            valid = False

        if size > 2:
            if size != len(set(keys)):
                logging.error(
                    'Project %s in file %s has duplicated parts',
                    item,
                    file_path)

                valid = False

            if set(keys) - VALID_PROJECT_PARTS:
                logging.warning(
                    'Project %s in file %s has unspecified parts. '
                    'The valid list is: %s',
                    item,
                    file_path,
                    VALID_PROJECT_PARTS)

    if not valid:
        exit(1)


def _is_valid_project_name(name, file_path, line_number):
    if (not PROJECT_NAMES_REGEX.match(name) and
        name not in REPOSITORIES_WHITELIST
    ):
        logging.error(
            'Project %s in file %s:%s has invalid name.',
            name,
            file_path,
            line_number)
        return False

    return True


def run_checks():
    for file_to_check in os.listdir('.'):
        if file_to_check.endswith('.yaml'):
            check_syntax(file_to_check)
            check_projects_sections(file_to_check)
            check_projects_names(file_to_check)


REPOSITORIES_WHITELIST = {
    'fuel-infra/backports/SDL2',
    'fuel-infra/backports/rubygem-safe_yaml',
    'fuel-infra/puppet-os_client_config',
    'infra/ci_status',
    'infra/release_scripts',
    'mos-infra/puppet-etherpad_lite',
    'mox-build/glance_store-build',
    'mox-packages/centos6/mod_ssl',
    'mox/glance_store',
    'openstack-build/django_openstack_auth-build',
    'openstack-build/glance_store-build',
    'openstack/django_openstack_auth',
    'openstack/glance_store',
    'packages/centos6/Cython',
    'packages/centos6/Django',
    'packages/centos6/Django14',
    'packages/centos6/GeoIP',
    'packages/centos6/MySQL',
    'packages/centos6/MySQL-python',
    'packages/centos6/MySQL-wsrep',
    'packages/centos6/PyYAML',
    'packages/centos6/libnetfilter_conntrack',
    'packages/centos6/libnetfilter_cthelper',
    'packages/centos6/libnetfilter_cttimeout',
    'packages/centos6/libnetfilter_queue',
    'packages/centos6/megaraid_sas',
    'packages/centos6/mod_fastcgi',
    'packages/centos6/mod_fcgid',
    'packages/centos6/mod_wsgi',
    'packages/centos6/node-autoNumeric',
    'packages/centos6/perl-DBD-MySQL',
    'packages/centos6/perl-LockFile-Simple',
    'packages/centos6/python-XStatic-Magic-Search',
    'packages/centos6/python-backports-ssl_match_hostname',
    'packages/centos6/python-ez_setup',
    'packages/centos6/python-glance_store',
    'packages/centos6/python-posix_ipc',
    'packages/centos6/python-pyasn1_modules',
    'packages/centos6/ruby21-rubygem-json_pure',
    'packages/centos6/rubygem-gem_plugin',
    'packages/centos6/rubygem-json_pure',
    'packages/centos6/wxGTK',
    'packages/centos7/Cython',
    'packages/centos7/Django',
    'packages/centos7/GitPython',
    'packages/centos7/MySQL-wsrep',
    'packages/centos7/PyYAML',
    'packages/centos7/Xaw3d',
    'packages/centos7/erlang-sd_notify',
    'packages/centos7/libnetfilter_cthelper',
    'packages/centos7/libnetfilter_cttimeout',
    'packages/centos7/python-BeautifulSoup',
    'packages/centos7/python-PyMySQL',
    'packages/centos7/python-WSGIProxy2',
    'packages/centos7/python-XStatic-bootswatch',
    'packages/centos7/python-XStatic-termjs',
    'packages/centos7/python-backports_abc',
    'packages/centos7/python-sphinx_rtd_theme',
    'packages/centos7/rubygem-Platform',
    'packages/centos7/rubygem-RedCloth',
    'packages/centos7/rubygem-deep_merge',
    'packages/centos7/rubygem-domain_name',
    'packages/centos7/rubygem-safe_yaml',
    'packages/centos7/rubygem-test_declarative',
    'packages/centos7/rubygem-thread_safe',
    'packages/centos7/rubygem-unf_ext',
    'packages/centos7/wxGTK',
    'packages/precise/MySQL-wsrep',
    'packages/precise/megaraid_sas',
    'packages/precise/mod_fastcgi',
    'packages/precise/python-XStatic-Magic-Search',
    'packages/precise/python-glance_store',
    'packages/precise/python-posix_ipc',
    'packages/precise/python-pyasn1_modules',
    'puppet-modules/puppet-mesos_dns'
}


if __name__ == '__main__':
    run_checks()
