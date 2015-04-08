#!/bin/bash

set -ex

# Trigger TPI CI

curl -sS "http://jenkins-tpi.bud.mirantis.net:8080/job/download_iso/buildWithParameters?token=DOIT&RELEASE=${ISO_VERSION}"

echo "Description string: <a href=\"${REPORTED_JOB_URL}\">$BUILD</a>"
