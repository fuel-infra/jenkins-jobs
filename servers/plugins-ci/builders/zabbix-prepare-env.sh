#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:${PATH}

VIRTUAL_ENV=/home/jenkins/venv-nailgun-tests-fpb3
if [ -f ${VIRTUAL_ENV}/bin/activate ]; then
  source ${VIRTUAL_ENV}/bin/activate
  echo "Python virtual env exist"
  git clone git://github.com/stackforge/fuel-plugins.git
  cd fuel-plugins
  pip install fuel-plugin-builder
else
  rm -rf ${VIRTUAL_ENV}
  virtualenv --system-site-packages  ${VIRTUAL_ENV}
  source ${VIRTUAL_ENV}/bin/activate
  git clone git://github.com/stackforge/fuel-plugins.git
  cd fuel-plugins
  pip install fuel-plugin-builder
fi


if [[ $GERRIT_REFNAME == *"refs/tags/"* ]]
then
    find . -name '*.erb' -print0 | xargs -0 -P1 -L1 -I '%' erb -P -x -T '-' % | ruby -c
    find . -name '*.pp' -print0 | xargs -0 -P1 -L1 puppet parser validate --verbose
    find . -name '*.pp' -print0 | xargs -0 -P1 -L1 puppet-lint \
          --fail-on-warnings \
          --with-context \
          --with-filename \
          --no-80chars-check \
          --no-variable_scope-check \
          --no-nested_classes_or_defines-check \
          --no-autoloader_layout-check \
          --no-class_inherits_from_params_class-check \
          --no-documentation-check \
          --no-arrow_alignment-check
    fpb --check  ./
    fpb --build  ./
    echo "Description string: ${GERRIT_REFNAME}"
else
    echo "Description string: Not a tag creation event"
    exit 1
fi

deactivate
