#!/bin/bash -xe

# Compare current changes with other git brach
#
# Env variables:
#   TERGET_BRANCH: git branch to compare to ("master" by default)
# Positional arguments:
#   1: CI server folder name to compare

br=`git branch | grep "*"`
CURRENT_BRANCH=${br/* /}
TOX_ENV=$1

git stash
git checkout ${TARGET_BRANCH:-master}
tox -e compare-xml-old ${TOX_ENV}
git checkout ${CURRENT_BRANCH}
git stash pop
tox -e compare-xml-new ${TOX_ENV}

diff -r ./output/old/${TOX_ENV}/ ./output/new/${TOX_ENV}/
