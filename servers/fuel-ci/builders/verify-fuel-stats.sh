#!/bin/bash

set -ex

cd collector
tox -v
cd ..

cd migration
tox -v
cd ..

cd analytics
tox -v
cd ..
