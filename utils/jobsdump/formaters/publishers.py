#!/usr/bin/env python

__FOR_PARENTS__ = {
    'publishers',
}

__SUBSTITUTES__ = {
    'hudson.tasks.ArtifactArchiver': 'archive',
    'hudson.plugins.descriptionsetter.'
    'DescriptionSetterPublisher': 'description-setter',
    'hudson.tasks.junit.JUnitResultArchiver': 'junit',

    'hudson.plugins.parameterizedtrigger.BuildTrigger':
    'trigger-parameterized-builds',

    'parameterized-trigger': 'trigger-parameterized-builds',
    'hudson.tasks.Mailer': 'email',
    'mailer': 'email',
    'hudson.plugins.emailext.ExtendedEmailPublisher': 'email-ext',
    'hudson.tasks.test.AggregatedTestResultPublisher': 'aggregate-tests',
}
