#!/bin/bash
set -ex

ARGS="-e SC2013"
if [ "${GERRIT_REFSPEC}" = "refs/heads/master" ]; then
  find "${WORKSPACE}" -name "*.sh" -type f -print0 | xargs -0 shellcheck "${ARGS}"
else
  git diff HEAD~1 --name-only --diff-filter=AM | grep ".sh$" | xargs --no-run-if-empty shellcheck "${ARGS}"
fi
