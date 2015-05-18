#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright (c) 2015 Mirantis Inc.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import sys
import random
import extendedjenkins
import re
import time
import os
import glob
import pickle
import xml.etree.ElementTree as ET
import collections


def clean_double_space(self, str):
    return re.sub("\s\s+", ' ', str)


class labelManager:
    def __init__(self):
        self.jenkins_url = None
        self.jenkins_conn = None
        self.jenkins_username = ''
        self.jenkins_password = ''
        self.probe_edge = None
        # how many nodes we want to use in this action?
        self.count_nodes = None
        self.selected_nodes = []
        self.labels = []
        self.action = None
        self.dumplabels_head = 'labelManager_'
        self.dumplabels_dir = '/tmp/'
        self.dumplabels_file = \
            self.dumplabels_dir + self.dumplabels_head + time.strftime(
                '%Y%m%d%H%M%S',
                time.localtime()
            ) + '.txt'
        self.tries = None
        self.remove_all_labels = False
        self.arg_parser = None
        self.args = None
        self.op_labels = collections.defaultdict(list)
        self.dryrun = False
        self.strict_check = True
        self.strict_max_pickups = 100

    def parse_error(self):
        self.arg_parser.error("Not all mandatory args passed!")

    def parse_args(self):
        self.arg_parser = argparse.ArgumentParser()
        self.arg_parser.add_argument(
            '--url',
            required=True,
            dest='url',
        )
        self.arg_parser.add_argument(
            '--action',
            required=True,
            dest='action',
            help='Select one of the actions: add, remove, restore.'
        )
        self.arg_parser.add_argument(
            '--username',
            required=False,
            dest='username',
        )
        self.arg_parser.add_argument(
            '--password',
            required=False,
            dest='password',
        )
        self.arg_parser.add_argument(
            '--probe-edge',
            required=False,
            type=int,
            default=25,
            dest='probe_edge',
        )
        self.arg_parser.add_argument(
            '--random-nodes',
            type=int,
            required=False,
            default=0,
            dest='count_nodes',
            help='How many nodes should be chosen automatically?',
        )
        self.arg_parser.add_argument(
            '--labels',
            required=False,
            action='store',
            nargs='*',
        )
        self.arg_parser.add_argument(
            '--tries',
            type=int,
            default=40,
            required=False,
            dest='tries',
        )
        self.arg_parser.add_argument(
            '--labels-rm-all',
            required=False,
            action='store_true',
            dest='labels_rm_all',
            help='Removes all labels from a node',
        )
        self.arg_parser.add_argument(
            '--nodes',
            required=False,
            dest='nodes',
            nargs='*',
        )
        self.arg_parser.add_argument(
            '--restore-file',
            required=False,
            dest='restore_file',
            help='Used for providing a file path to restore file',
            metavar="FILE"
        )
        self.arg_parser.add_argument(
            '--dry-run',
            required=False,
            dest='dryrun',
            action='store_true',
            help='Runs in the dry mode.'
        )
        self.arg_parser.add_argument(
            '--non-strict-rm-check',
            required=False,
            dest='non_strict_rm_check',
            action='store_true',
            help='Used in conjunction with --random-nodes parameter and remove \
                action. Disables the strict remove checking feature when the \
                one already picked node do not have all of the required \
                labels set.'
        )
        self.args = self.arg_parser.parse_args()

        self.jenkins_url = self.args.url
        self.action = self.args.action
        self.probe_edge = self.args.probe_edge
        self.count_nodes = self.args.count_nodes
        self.tries = self.args.tries

        # "validate" not required by default args
        if(not self.args.nodes):
            if(self.args.count_nodes < 1):
                self.parse_error()
        else:
            self.selected_nodes = self.args.nodes

        if(self.args.action == "add"):
            if(not self.args.labels):
                self.parse_error()
            else:
                self.labels = self.args.labels

        if(self.args.action == "remove"):
            if(not self.args.labels):
                if(not self.args.labels_rm_all):
                    self.parse_error()
                else:
                    self.remove_all_labels = True
            else:
                self.labels = self.args.labels

        if(self.args.non_strict_rm_check):
            self.strict_check = False
        else:
            if(self.count_nodes > 0):
                self.strict_check = True
        if(self.args.dryrun):
            self.dryrun = True
        if(self.args.username):
            self.jenkins_username = self.args.username
        if(self.args.password):
            self.jenkins_password = self.args.password

    def _append_label(self, node, node_cfg):
        # check if that label is not already there to prevent
        # potential duplicates
        label_iterator = 0
        node_xmled = ET.fromstring(node_cfg)
        label_xmled = node_xmled.find('label')
        # the label_xmled can be None type, when there are no labels assigned
        # on the Node.
        for label in self.labels:
            _label_xmled = label_xmled.text
            if _label_xmled is None:
                _label_xmled = ''
            if re.search(r'\b%s\b' % label, _label_xmled):
                print 'Label \'%s\' already set on %s. Skipping...' % (
                    label, node)
                continue
            else:
                label_iterator += 1
                # append new label at the end.
                _label_xmled += ' ' + label
                # clean any double WHs if any..
                _label_xmled = clean_double_space(
                    _label_xmled
                )
                label_xmled.text = _label_xmled
                node_cfg = ET.tostring(node_xmled)
        # apply now a new config
        if(self.dryrun):
            print "Dryrun is enabled. Printing modded node config only"
            print node_cfg
        else:
            self.jenkins_conn.reconfig_node(node, node_cfg)

    def _del_label(self, node, node_cfg):
        node_xmled = ET.fromstring(node_cfg)
        label_xmled = node_xmled.find('label')
        if(self.remove_all_labels):
            label_xmled.text = ''
            node_cfg = ET.tostring(node_xmled)
        else:
            for label in self.labels:
                _label_xmled = label_xmled.text
                if _label_xmled is None:
                    _label_xmled = ''
                # when run with strict checking, make sure that specific
                # label is present on node, before removing it.
                # if not = remove node from the list and return false.
                if(self.strict_check):
                    label_is = re.search(
                        r'\b%s\b' % label,
                        _label_xmled
                    )
                    if(not label_is):
                        print(
                            "Warning: there is no such label: %s on a node: %s"
                            % (label, node)
                        )
                        if(self.count_nodes > 0):
                            return False
                _label_re = re.compile(r'\b%s\b' % label)
                # remove label, match whole word
                _label = _label_re.sub(
                    '', _label_xmled
                )
                label_xmled.text = _label
                # clean any double WHs if any..
                label_xmled.text = clean_double_space(
                    label_xmled.text
                )
                node_cfg = ET.tostring(node_xmled)
        # apply now a new config
        if(self.dryrun):
            print "Dryrun is enabled. Printing modded node config only"
            print node_cfg
        else:
            self.jenkins_conn.reconfig_node(node, node_cfg)
        return True

    def jenkins_connect(self):
        try:
            self.jenkins_conn = extendedjenkins.Jenkins(
                self.jenkins_url,
                self.jenkins_username,
                self.jenkins_password,
            )
        except Exception:
            print "Error occured during connection to Jenkins"
            sys.exit(1)

    def choose_nodes(self):
        iter = 0
        pick_nodes = True
        if(self.strict_max_pickups < 1):
            print 'Error: strict check: Could not choose all of required nodes'
            sys.exit(1)
        while (pick_nodes):
            for node in self.jenkins_conn.get_nodes():
                # for node in faked_nodes:
                if(len(self.selected_nodes) < self.count_nodes and
                   self.tries > iter):
                    if(node['name'] != 'master' and node['name'] not in
                       self.selected_nodes and not node['offline']
                       ):
                        node_details = self.jenkins_conn.get_node_info(
                            node['name']
                        )
                        # within first iteration find and pickup an idle nodes
                        if(iter == 0):
                            if(node_details['idle'] == 'True'):
                                self.selected_nodes.append(node['name'])
                                print 'node {0} is idle! \
                                    Adding to list...'.format(node['name'])
                        else:
                            # we are in iter >=1.
                            # pickup busy nodes - do it in a more/less random
                            # fashion.
                            if(random.randrange(100) < self.probe_edge):
                                self.selected_nodes.append(node['name'])
                else:
                    # got all required slaves. break from the loop.
                    pick_nodes = False
                    break
            iter += 1

    def remove_labels(self):
        rm = False
        if(len(self.selected_nodes) != self.count_nodes and
           not self.args.nodes):
            print 'Not all of the requested nodes has been reached!'
        else:
            while(not rm):
                for node in self.selected_nodes:
                    # for each selected node get current config.
                    node_cfg = self.jenkins_conn.get_node_config(node)
                    rm = self._del_label(node, node_cfg)
                    # stric check on removals.
                    # valid only when randomly selecting nodes.
                    if(not rm):
                        if(self.strict_check):
                            if(self.count_nodes > 0):
                                # remove_label returned false - that node
                                # do not have required label. need to pick up
                                # another node instead.
                                # thus delete selected node from the list
                                try:
                                    self.selected_nodes.remove(node)
                                except ValueError:
                                    pass
                                # and choose a new node (hopefully)
                                self.choose_nodes()
                                # and decreate random_max_pickups counter value
                                # to prevent infinite loops.
                                self.strict_max_pickups -= 1
                # write into a file list of nodes for later labels restore...
                f = open(self.dumplabels_file, 'wb')
                pickle.dump(self.op_labels, f)
                f.close()

    def add_labels(self):
        # adds labels to the node
        for node in self.selected_nodes:
            node_cfg = self.jenkins_conn.get_node_config(node)
            self._append_label(node, node_cfg)

    def restore_labels(self):
        if(self.args.restore_file):
            self.dumplabels_file = self.args.restore_file
        else:
            self.dumplabels_file = max(
                glob.iglob(
                    os.path.join(
                        self.dumplabels_dir,
                        self.dumplabels_head + '*'
                    )),
                key=os.path.getctime
            )
        f = open(self.dumplabels_file, 'rb')
        self.op_labels = pickle.load(f)
        f.close()
        for node, labels in self.op_labels.iteritems():
            # get current config of a node
            node_cfg = self.jenkins_conn.get_node_config(node)
            for _label in labels:
                self.labels.append(_label)
            # append a new label
            self._append_label(node, node_cfg)

    def main(self):
        self.parse_args()
        self.jenkins_connect()
        if(self.count_nodes):
            self.choose_nodes()
        if(self.action == "add"):
                self.add_labels()
        if(self.action == "remove"):
            self.remove_labels()
        if(self.action == "restore"):
            self.restore_labels()
        print 'Selected node(s): %s' % self.selected_nodes

if __name__ == "__main__":
    label = labelManager()
    label.main()
