#!/usr/bin/env python

__FOR_PARENTS__ = {
    'project',
    'job'
}

__SUBSTITUTES__ = {
    'logRotator': 'logrotate',
    'displayName': 'display-name',
    'blockBuildWhenDownstreamBuilding': 'block-downstream',
    'blockBuildWhenUpstreamBuilding': 'block-upstream',
    'authToken': 'auth-token',
    'concurrentBuild': 'concurrent',
    'customWorkspace': 'workspace',
    'quietPeriod': 'quiet-period',
    'scmCheckoutRetryCount': 'retry-count',
    'assignedNode': 'node',
    'buildWrappers': 'wrappers',
    'git': 'git',
}

__LISTED__ = (
    'properties',
    'publishers',
    'scm',
    'wrappers',
    'builders',
)
