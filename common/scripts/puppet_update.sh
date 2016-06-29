#!/bin/bash

set -ex

sudo FACTER_ROLE="${FACTER_ROLE}" /usr/bin/puppet agent -vd --onetime --no-daemonize --noop

if [[ ${UPDATE_SLAVE} == "true" ]]; then
    sudo FACTER_ROLE="${FACTER_ROLE}" /usr/bin/puppet agent -vd --onetime --no-daemonize
fi

# prepare description
PUPPET_VERSION=$(cut -d ' ' -f 2 /var/lib/puppet/gitrevision.txt)

echo "Description string:" \
  "slave: <a href='${JENKINS_URL}computer/${NODE}'>${NODE}</a><br>" \
  "updated: <b>${UPDATE_SLAVE}</b><br>" \
  "${PUPPET_VERSION}"
