#!/bin/bash
set -ex

: "${PLUGINS_URL?}"
: "${PLUGINS?}"

rm -rvf  "${PLUGINS}"
mkdir -p "${PLUGINS}"

for _p in EXAMPLE_PLUGIN_PATH                   \
          EXAMPLE_PLUGIN_V3_PATH                \
          EXAMPLE_PLUGIN_V4_PATH                \
          SEPARATE_SERVICE_DB_PLUGIN_PATH       \
          SEPARATE_SERVICE_RABBIT_PLUGIN_PATH   \
          SEPARATE_SERVICE_KEYSTONE_PLUGIN_PATH \
          SEPARATE_SERVICE_HAPROXY_PLUGIN_PATH  \
          SEPARATE_SERVICE_BALANCER_PLUGIN_PATH ; do
    _plugin_path="${!_p}"
    _plugin_name="${_plugin_path##*\/}"
    curl -s "${PLUGINS_URL}${_plugin_name}" -o "${_plugin_path}"
done