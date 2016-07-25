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


def _get_merge_commit_message(repo, downstream_branch, upstream_branch,
                              change_id_seed):
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
    hashsum.update(downstream + change_id_seed)
    changeid = 'I' + hashsum.hexdigest()

    template = ('Merge the tip of %(upstream)s into %(downstream)s'
                '\n\n%(commits)s'
                '\n\nChange-Id: %(changeid)s')

    return template % {'upstream': upstream_branch,
                       'downstream': downstream_branch,
                       'changeid': changeid,
                       'commits': commits}


def _merge_tip(repo, downstream_branch, upstream_branch, change_id_seed):
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
        head_path = os.path.join(repo, '.git', 'HEAD')
        m = _get_merge_commit_message(repo, downstream_branch, upstream_branch,
                                      change_id_seed)

        state_before_merge = open(head_path, 'rt').read().strip()
        subprocess.check_output(
            ['git', 'merge', '--no-ff', '-m', m, upstream_branch],
            cwd=repo,
            stderr=subprocess.PIPE
        )
        state_after_merge = open(head_path, 'rt').read().strip()

        # merge can also succeed as a no-op, which is fine, but we need to skip
        # uploading of a merge commit in this case, as there is no merge commit
        if state_before_merge == state_after_merge:
            LOG.info('Branch is already up-to-date. Do nothing.')
            return None
    except subprocess.CalledProcessError, e:
        LOG.error(e.output)
        raise FailedToMerge
    else:
        LOG.info('Commit message:\n\n%s\n\n', m)
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

    all_outp = stdout + '#' + stderr

    if process.returncode:
        if 'no changes made' in all_outp or 'no new changes' in all_outp:
            LOG.info('No changes since the last sync. Skip.')
        else:
            LOG.error('Failed to push the commit %s to %s:\n\n%s',
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


def _branch_exists(repo, branch):
    if not branch.startswith('origin/'):
        branch = 'origin/' + branch

    LOG.info('Checking if branch %s exists...', branch)

    output = subprocess.check_output(
        ['git', 'branch', '-r'],
        cwd=repo
    )

    existing_branches = [b.strip(' \t*') for b in output.splitlines()]
    LOG.debug('Existing branches:\n%s', '\n'.join(existing_branches))

    return branch in existing_branches


def sync_project(gerrit_uri, downstream_branch, upstream_branch, topic=None,
                 dry_run=False, fallback_branch=None, change_id_seed=''):
    '''Merge the tip of the tracked upstream branch and upload it for review.

    Tries to clone (fetch, if path already exists) the git repo and do a
    non-fastforward merge of the tip of the tracked upstream branch into
    downstream one, and then upload the resulting merge commit for review.

    If automatic merge fails due to conflicts, FailedToMerge exception is
    raised.

    :param gerrit_uri: gerrit git repo uri
    :param downstream_branch: name of the downstream branch
    :param upstream_branch: name of the corresponding upstream branch
    :param fallback_branch: name of the branch to be used if the given upstream
                            branch does not exist
    :param topic: a Gerrit topic to be used
    :param dry_run: don't actually upload commits to Gerrit, just try to merge
                    the branch locally
    :param change_id_seed: customize Gerrit Change ID by appending some custom
                           string to current downstream head SHA-1

    :returns merge commit id

    '''

    repo = _clone_or_fetch(gerrit_uri)
    try:
        if not _branch_exists(repo, upstream_branch) and fallback_branch:
            LOG.info(
                'Upstream branch %s is missing, using %s instead...',
                upstream_branch, fallback_branch)
            upstream_branch = fallback_branch

        commit = _merge_tip(repo, downstream_branch, upstream_branch,
                            change_id_seed)

        if dry_run:
            LOG.info('Dry run, do not attempt to upload the merge commit')
        elif commit:
            _upload_for_review(repo, commit, downstream_branch, topic=topic)

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
        '--fallback-branch',
        help=('branch to sync the state from if the given '
              'upstream branch does not exist. Useful to have '
              'code sync enabled in advance, when the corresponding '
              'upstream has not been cut yet '
              '(defaults to $SYNC_FALLBACK_BRANCH)'),
        default=os.getenv('SYNC_FALLBACK_BRANCH', None)
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

    parser.add_argument(
        '--change-id-seed',
        help=('customize Gerrit Change ID by appending some custom string '
              'to current downstream head SHA-1 '
              '(defaults to $JOB_NAME)'),
        default=os.getenv('JOB_NAME', '')
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
                              fallback_branch=args.fallback_branch,
                              topic=args.topic,
                              dry_run=args.dry_run,
                              change_id_seed=args.change_id_seed)
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
