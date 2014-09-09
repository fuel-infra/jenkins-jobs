#!/usr/bin/env python

__FOR_PARENTS__ = {
    'configuredTriggers',
}

__SUBSTITUTES__ = {
    'hudson.plugins.emailext.plugins.trigger.AlwaysTrigger': 'always',
    'hudson.plugins.emailext.plugins.trigger.UnstableTrigger': 'unstable',

    'hudson.plugins.emailext.plugins.trigger.FirstFailureTrigger':
    'first-failure',

    'hudson.plugins.emailext.plugins.trigger.NotBuiltTrigger': 'not-built',
    'hudson.plugins.emailext.plugins.trigger.AbortedTrigger': 'aborted',
    'hudson.plugins.emailext.plugins.trigger.RegressionTrigger': 'regression',
    'hudson.plugins.emailext.plugins.trigger.FailureTrigger': 'failure',

    'hudson.plugins.emailext.plugins.trigger.SecondFailureTrigger':
    'second-failure',

    'hudson.plugins.emailext.plugins.trigger.ImprovementTrigger':
    'improvement',

    'hudson.plugins.emailext.plugins.trigger.StillFailingTrigger':
    'still-failing',

    'hudson.plugins.emailext.plugins.trigger.SuccessTrigger': 'success',
    'hudson.plugins.emailext.plugins.trigger.FixedTrigger': 'fixed',
    'hudson.plugins.emailext.plugins.trigger.StillUnstableTrigger':
    'still-unstable',

    'hudson.plugins.emailext.plugins.trigger.PreBuildTrigger': 'pre-build',
}
