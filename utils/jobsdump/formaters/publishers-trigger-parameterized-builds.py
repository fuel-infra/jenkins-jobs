#!/usr/bin/env python

__FOR_PARENTS__ = {
    'trigger-parameterized-builds',
}

__SUBSTITUTES__ = {
    'configs': 'configs__up__',
    'hudson.plugins.parameterizedtrigger.BuildTriggerConfig':
    'hudson.plugins.parameterizedtrigger.BuildTriggerConfig__up__',

    'hudson.plugins.parameterizedtrigger.PredefinedBuildParameters':
    'predefined-parameters',
}
