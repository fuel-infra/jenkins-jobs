#!/bin/bash

set -e

source /etc/profile

HOTPLUGGABLE_V4_PATH="./examples/fuel_plugin_example_v4_hotpluggable"
rm -rf $HOTPLUGGABLE_V4_PATH
cp -r ./examples/fuel_plugin_example_v4 $HOTPLUGGABLE_V4_PATH
sed -i -e "s/is_hotpluggable: false/is_hotpluggable: true/g" $HOTPLUGGABLE_V4_PATH/metadata.yaml
sed -i -e "s/fuel_plugin_example_v4/fuel_plugin_example_v4_hotpluggable/g" $HOTPLUGGABLE_V4_PATH/metadata.yaml

./run_tests.sh
