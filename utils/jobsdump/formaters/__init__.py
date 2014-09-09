#!/usr/bin/env python

import os

filelistmodules = os.listdir(os.path.dirname(__file__))
__all__ = sorted(
    os.path.splitext(name)[0] for name in filelistmodules if not (
        name.startswith('_') or
        name.startswith('.') or
        name.endswith('pyc') or
        name.endswith('py.off')))
del filelistmodules

RENAME_MAP = {}
LIST_MAP = {}


def loadAll():
    for module in __all__:
        module = __import__("formaters.%s" % module, fromlist=[''])
        for parents in module.__FOR_PARENTS__:
            if module.__SUBSTITUTES__ is not None:
                RENAME_MAP[parents] = module.__SUBSTITUTES__
            if hasattr(module, '__LISTED__'):
                LIST_MAP[parents] = module.__LISTED__


def rename(s, parent=None):
    if parent is None:
        if s == 'project':
            s = 'job'
        return s
    parent = str(parent.nodeName)
    if parent in RENAME_MAP:
        if s in RENAME_MAP[parent]:
            s = RENAME_MAP[parent][s]
    return s


def listinside(n, parent=None):
    if parent is None:
        return False
    parent = str(parent.nodeName)
    if parent in LIST_MAP:
        if n in LIST_MAP[parent]:
            return True
    return False

loadAll()
