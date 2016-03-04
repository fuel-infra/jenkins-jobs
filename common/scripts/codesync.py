#!/usr/bin/env python
# coding: utf-8

import argparse
import hashlib
import logging
import os
import subprocess
import sys
import urlparse


LOG = logging.getLogger('codesync')


class FailedToMerge(Exception):
    '''Raised when automatic merge fails due to conflicts.'''


def _clone_or_fetch(gerrit_uri):
    LOG.info('Cloning %s...', gerrit_uri)

    repo = os.path.basename(urlparse.urlsplit(gerrit_uri).path)

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


def _get_merge_commit_message(repo, downstream_branch, upstream_branch):
    downstream = _get_commit_id(repo, downstream_branch)
    upstream = _get_commit_id(repo, upstream_branch)

    LOG.info('Downstream commit id: %s', downstream)
    LOG.info('Upstream commit id: %s', upstream)

    commits_range = '%s..%s' % (downstream_branch, upstream_branch)
    commits = subprocess.check_output(
        ['git', 'log', '--no-merges', '--pretty=format:%h %s', commits_range],
        cwd=repo
    )

    hashsum = hashlib.sha1()
    hashsum.update(downstream)
    changeid = 'I' + hashsum.hexdigest()

    template = ('Merge the tip of %(upstream)s into %(downstream)s'
                '\n\n%(commits)s'
                '\n\nChange-Id: %(changeid)s')

    return template % {'upstream': upstream_branch,
                       'downstream': downstream_branch,
                       'changeid': changeid,
                       'commits': commits}


def _merge_tip(repo, downstream_branch, upstream_branch):
    LOG.info('Trying to merge the tip of %s into %s...',
             upstream_branch, downstream_branch)

    if not downstream_branch.startswith('origin/'):
        downstream_branch = 'origin/' + downstream_branch
    if not upstream_branch.startswith('origin/'):
        upstream_branch = 'origin/' + upstream_branch

    # print merge information for visibility purposes
    commits_range = '%s..%s' % (downstream_branch, upstream_branch)
    graph = subprocess.check_output(
        ['git', 'log', '--graph', '--pretty=format:%h %s', commits_range],
        cwd=repo
    )
    LOG.info('Commits graph to be merged:\n\n%s', graph)

    subprocess.check_call(
        ['git', 'checkout', downstream_branch],
        cwd=repo,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    try:
        m = _get_merge_commit_message(repo, downstream_branch, upstream_branch)
        LOG.info('Commit message:\n\n%s\n\n', m)

        subprocess.check_call(
            ['git', 'merge', '--no-ff', '-m', m, upstream_branch],
            cwd=repo,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
    except subprocess.CalledProcessError:
        raise FailedToMerge
    else:
        commit = _get_commit_id(repo)
        LOG.info('Merge commit id: %s', commit)
        return commit


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
        if 'no changes made' in stdout or 'no changes made' in stderr:
            LOG.info('No changes since the last sync. Skip.')
        else:
            LOG.error('Failed to push the commit %s to %s',
                      commit, branch, stderr)
            raise RuntimeError('Failed to push the commit %s to %s:\n\n%s' % (
                               commit, branch, stderr))


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


def sync_project(gerrit_uri, downstream_branch, upstream_branch, topic=None,
                 dry_run=False):
    '''Merge the tip of the tracked upstream branch and upload it for review.

    Tries to clone (fetch, if path already exists) the git repo and do a
    non-fastforward merge of the tip of the tracked upstream branch into
    downstream one, and then upload the resulting merge commit for review.

    If automatic merge fails due to conflicts, FailedToMerge exception is
    raised.

    :param gerrit_uri: gerrit git repo uri
    :param downstream_branch: name of the downstream branch
    :param upstream_branch: name of the corresponding upstream branch
    :param topic: a Gerrit topic to be used
    :param dry_run: don't actually upload commits to Gerrit, just try to merge
                    the branch locally

    :returns merge commit id

    '''

    repo = _clone_or_fetch(gerrit_uri)
    try:
        commit = _merge_tip(repo, downstream_branch, upstream_branch)

        if not dry_run:
            _upload_for_review(repo, commit, downstream_branch, topic=topic)
        else:
            LOG.info('Dry run, do not attempt to upload the merge commit')

        return commit
    finally:
        _cleanup(repo)


def main():
    logging.basicConfig(
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    LOG.setLevel(logging.INFO)

    parser = argparse.ArgumentParser(
        description=('Merge the tip of the upstream tracking branch and '
                     'upload it for review. Merge commit id is printed '
                     'to stdout on success. If automatic merge fails '
                     'the process ends with a special exit code - 1. '
                     'All other exit codes (except 0 and 1) are runtime '
                     'errors.')
    )

    parser.add_argument(
        '--gerrit-uri',
        help=('Gerrit repo URI '
              '(defaults to $SYNC_GERRIT_URI)'),
        default=os.getenv('SYNC_GERRIT_URI')
    )
    parser.add_argument(
        '--downstream-branch',
        help=('downstream branch to upload merge commit to '
              '(defaults to $SYNC_DOWNSTREAM_BRANCH)'),
        default=os.getenv('SYNC_DOWNSTREAM_BRANCH')
    )
    parser.add_argument(
        '--upstream-branch',
        help=('upstream branch to sync the state from '
              '(defaults to $SYNC_UPSTREAM_BRANCH)'),
        default=os.getenv('SYNC_UPSTREAM_BRANCH')
    )
    parser.add_argument(
        '--topic',
        help='a Gerrit topic to be used',
        default=os.getenv('SYNC_GERRIT_TOPIC')
    )
    parser.add_argument(
        '--dry-run',
        help="do not upload a merge commit on review - just try local merge",
        default=bool(int(os.getenv('SYNC_DRY_RUN', 0))),
        action='store_true'
    )

    try:
        args = parser.parse_args()
        if (not args.gerrit_uri or
                not args.downstream_branch or
                not args.upstream_branch):
            parser.print_usage()
            raise ValueError('Required arguments not passed')

        commit = sync_project(gerrit_uri=args.gerrit_uri,
                              downstream_branch=args.downstream_branch,
                              upstream_branch=args.upstream_branch,
                              topic=args.topic,
                              dry_run=args.dry_run)
        print(commit)
    except FailedToMerge:
        # special case - expected error - automatic merge is not possible
        LOG.error('Automatic merge failed. Abort.')
        sys.exit(1)
    except Exception:
        # unhandled runtime errors
        LOG.exception('Runtime error: ')
        sys.exit(2)


if __name__ == '__main__':
    main()
