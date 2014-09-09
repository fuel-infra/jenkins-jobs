#!/usr/bin/env python

__FOR_PARENTS__ = {
    'builders',
}

__SUBSTITUTES__ = {
    'hudson.tasks.Shell': 'shell',
    'hudson.plugins.parameterizedtrigger.TriggerBuilder': 'trigger-builds',
}
