#!/usr/bin/env python

__FOR_PARENTS__ = {
    'wrappers',
}

__SUBSTITUTES__ = {
    'hudson.plugins.ansicolor.AnsiColorBuildWrapper': 'ansicolor',
    'hudson.plugins.build__timeout.BuildTimeoutWrapper': 'timeout',
}
