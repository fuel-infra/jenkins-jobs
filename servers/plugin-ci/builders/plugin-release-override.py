#!./venv_release/bin/python

"""
  ============================================

  .. module:: plugin-release-override.py
      :platform: Unix
      :synopsis: Script used to update release version in single fuel plugin
  .. vesionadded:: MOS-9.0
  .. vesionchanged:: MOS-9.0
  .. author:: Alexey Zvyagintsev <azvyagintsev@mirantis.com>


  This script is used to update single fuel plugin release version, to
  current timestamp. Script update metadata.yaml file, in PLUGIN_DIR folder.
  Example:
    $ cat metadata.yaml|grep build_version
      build_version: '1' # Or not set at all
    $ rpm -qip plugin-1.0-1.0.0-1.noarch.rpm
      Release     : 1
    >
    $ cat metadata.yaml|grep build_version
      build_version: '20160830133410'
    $ rpm -qip plugin-1.0-1.0.0-20160830133410.noarch.rpm
      Release     : 20160830133410


  .. envvar::
      :var  PLUGIN_DIR: Path to directory with plugin code
      :var PLUGIN_RELEASE_TIMESTAMP: boolean
      If true - script will update release

  .. requirements::

      * slave with hiera enabled:
          fuel_project::jenkins::slave::build_fuel_packages: true

      * fpb patch https://review.openstack.org/#/c/362016/

  .. affects::
      * WARNING! Depended on script prepare-plugin-release-override.sh -
        shebang line should be same with prepared venv path

"""

import os
import sys
import time
import yaml

_boolean_states = {'1': True, 'yes': True, 'true': True, 'on': True,
                   '0': False, 'no': False, 'false': False, 'off': False}


def get_var_as_bool(name, default):
    value = os.environ.get(name, '')
    return _boolean_states.get(value.lower(), default)

if __name__ == '__main__':

    if not get_var_as_bool('PLUGIN_RELEASE_TIMESTAMP', False):
        sys.exit(0)
    plugin_dir = os.environ.get("PLUGIN_DIR")
    yaml_file = os.path.join(plugin_dir, 'metadata.yaml')
    if os.path.exists(yaml_file):
        print('INFO:Plugin metadata file:{}'.format(yaml_file))
    else:
        print('ERROR:Metadata file:{} not exist!'.format(yaml_file))
        sys.exit(1)

    with open(yaml_file, 'r') as f:
        i_yaml = yaml.safe_load(f)
    print('INFO:Old plugin release version:{}'.format(
        i_yaml.get('build_version', 'Not set')))
    i_yaml['build_version'] = str(time.strftime("%Y%m%d%H%M%S"))

    with open(yaml_file, 'w') as f:
        f.write(yaml.safe_dump(i_yaml))
    print('INFO:New plugin release version:{}'.format(i_yaml['build_version']))
