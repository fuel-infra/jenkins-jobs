#!/usr/bin/env python
# coding: utf-8

import argparse
import collections
import logging
import os
import re
import subprocess
import sys
import urlparse


LOG = logging.getLogger('custompatches')


PATTERN = re.compile(r'''
    commit\s(?P<commitid>[a-f0-9]{40})       # git commit id
    .*?                                      # lazily skip to the very bottom
    Change-Id:\s(?P<changeid>I[a-f0-9]{40})  # gerrit change id
    .*?\n\n                                  # lazily skip to the very bottom
    ''',
    re.DOTALL | re.VERBOSE  # match newlines with .* and allow whitespaces
)

CLOSED_RE = re.compile(r'.*\(change \d+ closed\).*', re.DOTALL)


def _clone_or_fetch(gerrit_uri):
    LOG.info('Cloning %s...', gerrit_uri)

    repo = os.path.basename(
        urlparse.urlsplit(gerrit_uri).path
    ).partition('.git')[0]  # split trailing .git, if necessary

    retcode = subprocess.call(
        ['git', 'clone', '-q', gerrit_uri],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if retcode:
        if not os.path.exists(repo):
            LOG.error('Failed to clone repo: %s', gerrit_uri)
            raise RuntimeError('Failed to clone repo: %s' % gerrit_uri)
        else:
            LOG.info('Repo already exits, fetch the latest state...')

            subprocess.check_call(
                ['git', 'reset', '--hard', 'HEAD'],
                cwd=repo,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            subprocess.check_call(
                ['git', 'remote', 'update'],
                cwd=repo,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )

    path = os.path.join(os.getcwd(), repo)
    LOG.info('Updated repo at: %s', path)
    return path


def _get_commit_id(repo, ref='HEAD'):
    return subprocess.check_output(
        ['git', 'show', ref],
        cwd=repo
    ).splitlines()[0].split()[1]


def _get_commit_info(repo, ref='HEAD'):
    return subprocess.check_output(
        ['git', 'show', '--oneline', ref],
        cwd=repo
    ).splitlines()[0].strip()


def _upload_for_review(repo, commit, branch, topic=None):
    LOG.info('Uploading commit %s to %s for review...', commit, branch)

    pusharg = '%s:refs/for/%s' % (commit, branch)
    if topic:
        pusharg += '%topic=' + str(topic)

    process = subprocess.Popen(
        ['git', 'push', 'origin', pusharg],
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    stdout, stderr = process.communicate()

    if process.returncode:
        if 'no changes' in stderr:
            LOG.info('No changes in %s, skipping it...', commit)
            return
        if CLOSED_RE.match(stderr):
            LOG.info('Change %s is closed in Gerrit, skipping it...', commit)
            return

        LOG.error('Failed to push the commit %s to %s', (commit, branch))
        raise RuntimeError(
            'Failed to push the commit %s to %s' % (commit, branch)
        )


def _cleanup(repo):
    LOG.info('Running cleanups (hard reset + checkout of master + gc)...')

    subprocess.check_call(
        ['git', 'reset', '--hard', 'HEAD'],
        cwd=repo,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    subprocess.check_call(
        ['git', 'checkout', 'master'],
        cwd=repo,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    subprocess.check_call(
        ['git', 'gc'],
        cwd=repo,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )

    LOG.info('Cleanups done.')


def _get_commits_info(repo, start, end):
    res = collections.OrderedDict()

    output = subprocess.check_output(
        ['git', 'log', '--no-merges', '--reverse', '%s..%s' % (start, end)],
        cwd=repo,
    )
    for match in re.finditer(PATTERN, output):
        info = match.groupdict()
        res[info['changeid']] = info['commitid']

    return res


def _get_custom_patches(repo, old_branch, new_branch):
    if not old_branch.startswith('origin/'):
        old_branch = 'origin/' + old_branch
    if not new_branch.startswith('origin/'):
        new_branch = 'origin/' + new_branch

    common_ancestor = subprocess.check_output(
        ['git', 'merge-base', new_branch, old_branch],
        cwd=repo
    ).strip()

    old_commits = _get_commits_info(repo, common_ancestor, old_branch)
    new_commits = _get_commits_info(repo, common_ancestor, new_branch)

    commits = {}
    for changeid in (old_commits.viewkeys() - new_commits.viewkeys()):
        commits[changeid] = old_commits[changeid]

    return commits


def upload_patches(gerrit_uri, old_branch, new_branch,
                   topic=None, dry_run=False):
    repo = _clone_or_fetch(gerrit_uri)
    try:
        patches = _get_custom_patches(repo, old_branch, new_branch)

        LOG.info('Start processing patches...')
        for changeid, commitid in patches.items():
            subprocess.check_call(
                ['git', 'checkout', commitid],
                cwd=repo,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )

            output = subprocess.check_output(
                ['git', 'commit', '--amend', '--no-edit'],
                cwd=repo,
                stderr=subprocess.STDOUT
            )
            if '--allow-empty' in output:
                continue

            new_commit_id = _get_commit_id(repo)
            if not dry_run:
                _upload_for_review(repo, new_commit_id, new_branch, topic)
            else:
                LOG.info(_get_commit_info(repo, new_commit_id))
        LOG.info('Upload complete')
    finally:
        _cleanup(repo)


def main():
    logging.basicConfig(
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    LOG.setLevel(logging.INFO)

    parser = argparse.ArgumentParser(
        description=('Upload on review patches from the <old branch>, '
                     'which are not in the <new branch>.')
    )

    parser.add_argument(
        '--gerrit-uri',
        help='Gerrit repo URI',
        default=os.getenv('CUSTOM_PATCHES_GERRIT_URI')
    )
    parser.add_argument(
        '--old-branch',
        help='old branch to take patches from (typically, previous release)',
        default=os.getenv('CUSTOM_PATCHES_OLD_BRANCH')
    )
    parser.add_argument(
        '--new-branch',
        help='new branch to push patches to (typically, current release)',
        default=os.getenv('CUSTOM_PATCHES_NEW_BRANCH')
    )
    parser.add_argument(
        '--topic',
        help='a Gerrit topic name to use',
        default=os.getenv('CUSTOM_PATCHES_TOPIC'),
    )
    parser.add_argument(
        '--dry-run',
        help='do not upload patches on review, just log them',
        default=bool(int(os.getenv('CUSTOM_PATCHES_DRY_RUN', 0))),
        action='store_true'
    )

    args = parser.parse_args()

    if (not args.gerrit_uri or
            not args.old_branch or
            not args.new_branch):
        parser.error('gerrit-uri, old-branch, new-branch are required')

    try:
        upload_patches(gerrit_uri=args.gerrit_uri,
                       new_branch=args.new_branch,
                       old_branch=args.old_branch,
                       topic=args.topic,
                       dry_run=args.dry_run)
    except Exception:
        LOG.exception('Error while processing patches: ')
        sys.exit(1)


if __name__ == '__main__':
    main()
