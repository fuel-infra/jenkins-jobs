#!/usr/bin/env python

__FOR_PARENTS__ = {
    'extended-choice',
}

__SUBSTITUTES__ = {
    'parameterDefinitions': 'extended-choice',
    'hudson.model.ChoiceParameterDefinition': 'extended-choice',
    'quoteValue': 'quote-value',
    'visibleItemCount': 'visible-items',

    'hudson.model.StringParameterDefinition':
    'hudson.model.StringParameterDefinition__up__',
}
