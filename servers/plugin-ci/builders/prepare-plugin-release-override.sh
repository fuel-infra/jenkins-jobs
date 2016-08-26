#!/bin/bash
#
#   :mod: `prepare-plugin-release-override.sh` -- Update plugin release
#   ============================================
#
#   .. module:: prepare-plugin-release-override.sh
#       :platform: Unix
#       :synopsis: Script used to update release version in single fuel plugin
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Alexey Zvyagintsev <azvyagintsev@mirantis.com>
#
#
#   This script is used to prepare env, for run plugin-release-override.py
#
#   .. envvar::
#       :var  PLUGIN_DIR: Path to directory with plugin code
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::build_fuel_packages: true
#
#       * fpb patch https://review.openstack.org/#/c/362016/
#
#   .. affects::
#       * Depended script plugin-release-override.py - shebang line
#         should be same with prepared venv path
#

set -ex

# We should create venv, even if we don't wan't to change release version
echo "INFO: Preparing env for script which will be used for release override"
if [ -d ./plugin-release-override-venv ] ; then
  rm -rf "./plugin-release-override-venv"
fi
virtualenv ./plugin-release-override-venv
source ./plugin-release-override-venv/bin/activate
  pip install pyyaml
deactivate
