#!/bin/bash
#
#   :mod: `build_plugin.sh` -- Build fuel plugin
#   ============================================
#
#   .. module:: build_plugin.sh
#       :platform: Unix
#       :synopsis: Script used to build single fuel plugin
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Artur Kaszuba <akaszuba@mirantis.com>
#
#
#   This script is used to build single fuel plugin and store variables
#   which could be used to execute deployment test
#
#
#   .. envvar::
#       :var  PLUGIN_DIR: Path to directory with plugin code
#       :type PLUGIN_DIR: path
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::build_fuel_packages: true
#
#
#   .. affects::
#       :file build_plugin.envfile: file with variables used by deployment job
#


set -o errexit
set -o pipefail
set -o xtrace

echo "INFO: Prepare VENV for plugin build"
rm -rf ./venv_fpb
virtualenv ./venv_fpb
source ./venv_fpb/bin/activate

echo "INFO:  Install fpb"
pip install ./fuel-plugins/

echo "INFO: Check and build plugin from ${PLUGIN_DIR}"
fpb --check  "${PLUGIN_DIR}"
fpb --debug --build  "${PLUGIN_DIR}"

# Find rpm file with plugin
PLUGIN_FILE=$(basename "$(ls "${PLUGIN_DIR}"/*.rpm)")

# Store variables for deployment test
cat << EOF >build_plugin.envfile
PLUGIN_FILE=${PLUGIN_FILE}
PLUGIN_FILE_PATH=${WORKSPACE}/${PLUGIN_DIR}/${PLUGIN_FILE}
PKG_PATH=${WORKSPACE}/${PLUGIN_DIR}
BUILD_HOST=${BUILD_HOST}
EOF
echo "INFO: Plugin build finished"
