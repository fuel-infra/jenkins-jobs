#!/usr/bin/env python

"""
   :mod: `spacefinder` -- utility that counts used disc space
   ===================================================
   .. module:: spacefinder.py
      :platform: Linux, Ubuntu
      :synopsis: Counts amount of disc space
   .. author:: Sergey Otpuschennikov <sotpuschennikov@mirantis.com>

   This script finds qemu images, created by fuel-devops
   and counts the total amount of space they occupy on file system.
   May run in manual mode e.g ``spacefinder.py -e env_name``
   or without parameter if ENV_NAME environment variable is defined
"""

import argparse
import logging
import os
import re

import libvirt

from xml.dom import minidom

if os.environ.get('VENV_PATH'):
    activate_this = os.environ.get('VENV_PATH') + "/bin/activate_this.py"
    execfile(activate_this, dict(__file__=activate_this))

try:
    import devops
    from devops.models import environment
except ImportError:
    devops = None


def find_libvirt(env_name):
    """Look for environments qemu images and counting space
    they occupy on file system using by libvirt API

    :param env_name: fuel-devops environment name
    :type: env_name: string

    :return: sum of images sizes in Mbytes
    :rtype: int
    """
    conn = libvirt.openReadOnly('qemu:///system')
    if conn is None:
        raise RuntimeError('Failed to open connection to the hypervisor')
    list_domains = conn.listDefinedDomains()
    r_dom=re.compile(env_name)
    summ = 0
    if filter(r_dom.match, list_domains):
        for domain in list_domains:
            if env_name in domain:
                # getting configuration of libvirt domain in xml format
                # result is identical to output ``virsh dumpxml domain``
                raw_xml = conn.lookupByName(domain).XMLDesc(0)
                xml = minidom.parseString(raw_xml)
                sourceFiles = xml.getElementsByTagName('source')
                for sourceFile in sourceFiles:
                    if sourceFile.getAttribute('file'):
                        summ += os.path.getsize(sourceFile.getAttribute('file'))
        # return used disc space in Mbytes
        conn.close()
        return summ/1024/1024
    else:
        conn.close()
        raise RuntimeError("Libvirt domains are not exist")


def find_devops(env_name):
    """Look for environments qemu images and counting space
    they occupy on file system using by fuel-devops

    :param env_name: fuel-devops environment name
    :type: env_name: string

    :return: sum of images sizes in Mbytes
    :rtype: int
    """
    if devops is not None:
        summ = 0
        env = environment.Environment.get(name=env_name)
        if devops.__version__.split('.')[0] == '2':
            for volume in env.get_volumes():
                summ += os.path.getsize(volume.get_path())
        elif devops.__version__.split('.')[0] == '3':
            for node in env.get_nodes():
                volumes = node.get_volumes()
                for volume in volumes:
        # Test exist image file because fuel-devops 3.0 can create
        # multinode environment
                    if os.path.isfile(volume.get_path()):
                        summ += os.path.getsize(volume.get_path())
        # return used disc space in Mbytes
        return summ/1024/1024
    else:
        raise RuntimeError("Can't import devops")


def parse_cli_arguments():
    """Parse the CLI arguments"""
    parser = argparse.ArgumentParser()
    parser.add_argument('-e', '--env-name', type=str,
                        default=os.environ.get('ENV_NAME', None),
                        help="Fuel-devops environment name")
    ways = ['devops', 'libvirt']
    parser.add_argument('-w', '--way', type=str, default=ways,
                        choices=ways,
                        help="Direct use fuel-devops or libvirt "
                        "for counting disc space. Used all the methods"
                        "by default")
    parser.add_argument('-f', '--file-name', type=str,
                        default="job_disk_space.txt", help="Output file name.")
    return parser.parse_args()


def write_artifact(env_name, summ, filename=None):
    """Write counted disk space message to stdout and to file if specified
    :param env_name: used fuel-devops environment name
    :type env_name: string

    :param summ: counted used disk space
    :type summ: string

    :param filename: filepath for result filename
    :type filename: string
    """

    msg = "{}={}".format(env_name, summ)
    logging.info(msg)
    if filename:
        with open(filename, 'w') as f:
            f.write(msg)


def main(env_name, artifact_file, way):

    """Look for environments qemu images and counting space
    they occupy on file system using by fuel-devops or libvirt API
    Write results to file and console.

    :param: env_name: fuel-devops environment name
    :type: env_name: string

    :param: artifact_file: output filepath
    :type: file object

    :param: way: method of counting
    :type: string
    """
    logging.basicConfig(format='%(levelname)s:%(message)s', level=logging.DEBUG)
    summ = 0
    # Default we try to count by both ways: fuel-devops and libvirt
    # If counting by one fuel-devops only
    if 'devops' in way:
        try:
            summ = find_devops(env_name)
            logging.info("Disc space is counted by fuel-devops")
            print("%s=%s\n" % (env_name, summ))
            write_artifact(env_name, summ, artifact_file)
            return
        except RuntimeError as error:
            logging.error("Disc space is not counted by fuel-devops")
            logging.error(format(error))
    # If counting by one libvirt only
    if 'libvirt' in way:
        try:
            summ = find_libvirt(env_name)
            logging.info("Disc space is counted by libvirt")
            write_artifact(env_name, summ, artifact_file)
            return
        except RuntimeError as error:
            logging.error("Disc space is not counted by libvirt")
            logging.error(format(error))
    raise RuntimeError("Disc space is not counted")

if __name__ == '__main__':
    args = parse_cli_arguments()
    if args.env_name:
        main(args.env_name, args.file_name, args.way)
    else:
        exit("Environment name is not specified. Use ENV_NAME "
             "environment variable or '-e' CLI parameter")
