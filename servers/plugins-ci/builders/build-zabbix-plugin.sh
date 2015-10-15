#!/bin/bash

set -ex

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

VIRTUAL_ENV=/home/jenkins/venv-nailgun-tests-fpb3
if [ -f $VIRTUAL_ENV/bin/activate ]; then
  source $VIRTUAL_ENV/bin/activate
  echo "Python virtual env exist"
  git clone git://github.com/openstack/fuel-plugins.git
  pushd .
  cd fuel-plugins
  cd fuel_plugin_builder
  pip install .
  popd
else
  rm -rf $VIRTUAL_ENV
  virtualenv --system-site-packages  $VIRTUAL_ENV
  source $VIRTUAL_ENV/bin/activate
  git clone git://github.com/openstack/fuel-plugins.git
  pushd .
  cd fuel-plugins
  cd fuel_plugin_builder
  pip install . 
  popd
fi


find deployment_scripts/ -name '*.erb' -print0 | xargs -0 -P1 -L1 -I '%' erb -P -x -T '-' % | ruby -c
find deployment_scripts/ -name '*.pp' -print0 | xargs -0 -P1 -L1 puppet parser validate --verbose
find deployment_scripts/ -name '*.pp' -print0 | xargs -0 -r -P1 -L1 puppet-lint \
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

if [ -f deployment_tasks.yaml ]; then
  echo "deployment_tasks.yaml exist"
else
  echo "creating deployment_tasks.yaml IT's dog-nail!!!"
  echo "[]" > deployment_tasks.yaml
fi

fpb --check  ./
fpb --build  ./

deactivate
