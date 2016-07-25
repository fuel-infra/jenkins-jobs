#!/bin/bash
#
#   :mod: `build-stacklight-plugins.sh` -- Build the StackLight plugins
#   ===================================================================
#
#   .. module:: build-stacklight-plugins.sh
#       :platform: Unix
#       :synopsis: Script used to build the StackLight plugins
#   .. vesionadded:: MOS-9.0
#   .. vesionchanged:: MOS-9.0
#   .. author:: Simon Pasquier <spasquier@mirantis.com>
#
#
#   This script is used to build the StackLight plugins as well as their
#   dependencies such as detach-database and detach-rabbitmq.
#
#
#   .. envvar::
#       :var  PLUGINS_DIR: Path to the base directory containing the plugins
#       :type PLUGINS_DIR: path
#
#   .. requirements::
#
#       * slave with hiera enabled:
#           fuel_project::jenkins::slave::build_fuel_packages: true
#
#
#   .. affects::
#       :file stacklight-build.jenkins-injectfile: file holding variables used
#       by the deployment job
#

# Source system variables with correct Ruby settings,
# include before "set" to skip not required messages
source /etc/profile

set -ex

# Setup a virtual environment and install fpb
rm -rf "${WORKSPACE}"/venv_fpb
virtualenv "${WORKSPACE}"/venv_fpb
source "${WORKSPACE}"/venv_fpb/bin/activate

pip install "${WORKSPACE}"/fuel-plugins/

function build_plugin {
    fpb --debug --build  "${PLUGINS_DIR}/$1"
}

function get_fullpath {
    ls "${PLUGINS_DIR}/$1/"*.rpm
}

ENV_FILE=stacklight-build.jenkins-injectfile

# Build all the plugins necessary for testing the StackLight toolchain
build_plugin fuel-plugin-elasticsearch-kibana
build_plugin fuel-plugin-influxdb-grafana
build_plugin fuel-plugin-lma-infrastructure-alerting
build_plugin fuel-plugin-lma-collector
build_plugin fuel-plugin-detach-database
build_plugin fuel-plugin-detach-rabbitmq

cat > "${ENV_FILE}" << EOF
ELASTICSEARCH_KIBANA_PLUGIN_PATH=$(get_fullpath fuel-plugin-elasticsearch-kibana)
INFLUXDB_GRAFANA_PLUGIN_PATH=$(get_fullpath fuel-plugin-influxdb-grafana)
LMA_INFRA_ALERTING_PLUGIN_PATH=$(get_fullpath fuel-plugin-lma-infrastructure-alerting)
LMA_COLLECTOR_PLUGIN_PATH=$(get_fullpath fuel-plugin-lma-collector)
DETACH_DATABASE_PLUGIN_PATH=$(get_fullpath fuel-plugin-detach-database)
DETACH_RABBITMQ_PLUGIN_PATH=$(get_fullpath fuel-plugin-detach-rabbitmq)
EOF
