#!/bin/bash
#
#   :mod: `plugin-verify.sh` -- Run unit tests for a Fuel plugin
#   ============================================================
#
#   .. module:: plugin-verify.sh
#       :platform: Unix
#       :synopsis: Script used to run the unit tests for a Fuel plugin
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Simon Pasquier <spasquier@mirantis.com>
#
#
#   This script is used to run the unit tests of a Fuel plugin using tox. It
#   also builds the documentation and the plugin package. Finally it stores
#   variables which could be used to execute the deployment test.
#
#
#   .. envvar::
#       :var  PLUGIN_DIR: Path to the directory containing the plugin code
#       :type PLUGIN_DIR: path
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::build_fuel_packages: true
#
#
#   .. affects::
#       :file plugin-verify.envfile: file with variables for the deployment job
#

# Source system variables with correct ruby settings,
# include before "set" to skip not required messages
source /etc/profile

set -ex

(cd "${PLUGIN_DIR}" && tox)

# Find the RPM file with plugin
PLUGIN_FILE=$(basename "$(ls "${PLUGIN_DIR}"/*.rpm)")

# Store variables for deployment test
cat << EOF >plugin-verify.envfile
PLUGIN_FILE=${PLUGIN_FILE}
PLUGIN_FILE_PATH=${WORKSPACE}/${PLUGIN_DIR}/${PLUGIN_FILE}
EOF

