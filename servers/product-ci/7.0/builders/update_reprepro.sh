#!/bin/bash -x
export OBSURL=https://obs-1.mirantis.com
for REPONAME in $REPOS; do
     ssh jenkins@${OBSURL##*/} "/home/jenkins/update-reprepro.sh $REPONAME"
done
