#!/usr/bin/env python

__FOR_PARENTS__ = {
    'userRemoteConfigs',
    'remotes',
}

__SUBSTITUTES__ = {
    'hudson.plugins.git.UserRemoteConfig':
    'hudson.plugins.git.UserRemoteConfig__up__',
}
