#!/usr/bin/env python

__FOR_PARENTS__ = {
    'properties',
}

__SUBSTITUTES__ = {
    'hudson.plugins.heavy__job.HeavyJobProperty': 'heavy-job',
    'hudson.plugins.throttleconcurrents.ThrottleJobProperty': 'throttle',
    'throttle-concurrents': 'throttle',
    'hudson.model.ParametersDefinitionProperty': 'extended-choice',
}
