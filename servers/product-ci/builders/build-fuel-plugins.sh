#!/bin/bash

#   :mod: `build-fuel-plugins.sh` -- this script builds Fuel plugins
#   ================================================================
#
#   .. module:: build-fuel-plugins.sh
#       :platform: Unix
#       :synopsys: this script builds plugins for Fuel project according to
#                  configuration yaml file. Resulted packages are stored in
#                  ${WORKSPACE}/built_plugins directory (both rpm and fp)
#   .. versionadded:: MOS-8.0
#   .. versionchanged:: MOS-9.0
#   .. author:: Lesya Novaselskaya <onovaselskaya@mirantis.com>
#
#
#   .. envvar::
#       :var WORKSPACE: build starter location, defaults to ``.``
#       :var HOTPLUGGABLE_V4_PATH:
#       :var BUILD_URL: Jenkins build URL link
#
#   .. requirements::
#       * valid configuration YAML file: build-fuel-plugins.yaml
#
#   .. seealso::
#
#   .. warnings::

set -ex

# to avoid Ruby versions conflicts for fpm ruby gem source /etc/profile
# (see details in https://bugs.launchpad.net/fuel/+bug/1584123)

source /etc/profile

HOTPLUGGABLE_V4_PATH="${WORKSPACE}/examples/fuel_plugin_example_v4_hotpluggable"
rm -rf "${HOTPLUGGABLE_V4_PATH}"
cp -r "${WORKSPACE}/examples/fuel_plugin_example_v4" "${HOTPLUGGABLE_V4_PATH}"
sed -i -e "s/is_hotpluggable: false/is_hotpluggable: true/g" \
    "${HOTPLUGGABLE_V4_PATH}/metadata.yaml"
sed -i -e "s/fuel_plugin_example_v4/fuel_plugin_example_v4_hotpluggable/g" \
    "${HOTPLUGGABLE_V4_PATH}/metadata.yaml"

./run_tests.sh

for plugin in built_plugins/*; do
    echo "<a href=\"${BUILD_URL}artifact/${plugin}\">$(basename "${plugin}")</a>"
done
