#!/bin/bash -x
export OBSURL=https://osci-obs.vm.mirantis.net
for REPONAME in $REPOS; do
     ssh jenkins@${OBSURL##*/} "/home/jenkins/update-reprepro.sh $REPONAME"
done
