#!/bin/bash

set -o xtrace
set -o errexit

source setenvfile
rm -f setenvfile

if [ -n "$RESULT" ] ; then
    exit "${RESULT}"
else
    exit 0
fi
