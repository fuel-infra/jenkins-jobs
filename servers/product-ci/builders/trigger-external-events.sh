#!/bin/bash

set -ex

# Trigger job on TPI CI

if [[ "${TRIGGER_ONLY_FOR_ISO_VERSION}" == "${ISO_VERSION}" ]]; then
    curl -sS "http://jenkins-tpi.bud.mirantis.net:8080/job/download_iso/buildWithParameters?token=b0a59406&RELEASE=${ISO_VERSION}"
    echo "Description string: <a href=\"${REPORTED_JOB_URL}\">$BUILD</a>"
else
    echo "Description string: Skipped for $BUILD"
fi

