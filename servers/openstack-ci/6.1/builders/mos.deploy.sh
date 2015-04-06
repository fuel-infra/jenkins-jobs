#!/bin/bash -ex

case "${GERRIT_PROJECT##*/}" in
    murano|murano-build)
        export SLAVE_NODE_MEMORY=6144
        export KEEP_BEFORE=no
        ;;
esac

if bash -ex package-testing; then
  echo FAILED=false >> ci_status_params
  EXITCODE=0
else
  echo FAILED=true >> ci_status_params
  EXITCODE=1
fi
exit $EXITCODE
