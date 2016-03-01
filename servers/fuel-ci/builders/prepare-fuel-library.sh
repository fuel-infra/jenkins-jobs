#!/bin/bash
source /etc/profile
set -ex

if [ -n "${GERRIT_PROJECT}" ]; then
  WORKDIR=${WORKSPACE}/fuel-library
  module=$(echo "${GERRIT_PROJECT}"|cut -d- -f 2)
  mv "${WORKSPACE}/upstream_module/${GERRIT_PROJECT}" "${WORKDIR}/deployment/puppet/${module}"
  cd "${WORKDIR}/deployment"
  ./update_modules.sh -b
  cd "${WORKDIR}/deployment/puppet"
  tar czvf "${WORKDIR}/files/upstream_modules.tar.gz" .
  #FIXME: Looks like there's no way to pass upstream modules through %{_sourcedir} using perestroika scripts
  sed -i "s|%{_sourcedir}|%{files_source}|" "${WORKDIR}/specs/${PROJECT_PACKAGE}.spec"
fi
