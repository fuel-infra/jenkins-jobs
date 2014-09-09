#!/usr/bin/env python

__FOR_PARENTS__ = {
    'hudson.plugins.throttleconcurrents.ThrottleJobProperty',
    'throttle',
}

__SUBSTITUTES__ = {
    'maxConcurrentPerNode': 'max-per-node',
    'axConcurrentTotal': 'max-total',
    'throttleEnabled': 'enabled',
    'throttleOption': 'option',
}
