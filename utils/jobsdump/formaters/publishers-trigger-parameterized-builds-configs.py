#!/usr/bin/env python

__FOR_PARENTS__ = {
    'configs',
    'hudson.plugins.parameterizedtrigger.BuildTriggerConfig',
}

__SUBSTITUTES__ = {
    'hudson.plugins.parameterizedtrigger.BuildTriggerConfig':
    'hudson.plugins.parameterizedtrigger.BuildTriggerConfig__up__',

    'hudson.plugins.parameterizedtrigger.PredefinedBuildParameters':
    'predefined-parameters',

    'configs': 'configs__up__',
    'hudson.plugins.parameterizedtrigger.FileBuildParameters': 'property-file',
}
