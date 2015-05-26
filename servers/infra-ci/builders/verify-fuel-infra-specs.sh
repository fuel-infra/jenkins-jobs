#!/bin/bash

set -ex

# build documentation
tox -v

# archive documentation
tar cvjf "${WORKSPACE}/archive.tar.bz2" -C build/html .
