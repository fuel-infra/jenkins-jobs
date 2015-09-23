#!/bin/bash

set -ex

rm -f magnet_link.txt
MAGNET_LINK="{iso_magnet_link}"

if [ ${{MAGNET_LINK}} = 'latest' ]
then
    curl -sSf -O https://product-ci.infra.mirantis.net/job/{mos_version}.test_all/lastSuccessfulBuild/artifact/magnet_link.txt
else
    echo "MAGNET_LINK=${{MAGNET_LINK}}" > magnet_link.txt
fi
