import requests
from pprint import pformat
import re


class Jenkins:

    def __init__(self, url):
        self.url = url.rstrip("/")

    def get_nodes_for_label(self, label):
        json_url = "/".join([self.url, "label", label, "api", "json"])
        r = requests.get(json_url)
        nodes = [node['nodeName'] for node in r.json()['nodes']]
        return nodes

    def get_nodes(self, online_only=True):
        json_url = "/".join([self.url, "computer", "api", "json"])
        r = requests.get(json_url)
        nodes = [
            node['displayName'] for node in r.json()['computer'] if not
            (
                online_only and (node['offline'] or node['temporarilyOffline'])
            )
        ]
        return nodes

    def list_nodes(self, label=None, names=None, online_only=True):

        nodes = self.get_nodes(online_only=online_only)

        if label:
            all_labeled_nodes = self.get_nodes_for_label(label)
            nodes = [node for node in nodes if node in all_labeled_nodes]

        if names:
            nodes = [node for node in nodes if re.match(names, node)]

        return sorted(nodes)


class Result():
    def __init__(self):
        self.data = {}

    def add_entry(self, host, entry):
        if host in self.data.keys():
            self.data[host].append(entry)
        else:
            self.data[host] = [entry]

    def formatted(self, fmt='txt'):

        if fmt == 'raw':
            return str(self.data)

        if fmt == 'txt':
            return pformat(self.data)

        if fmt == 'csv':
            csv_output = ""
            for host_entry in self.data.keys():
                for (entry_name, entry_data) in self.data[host_entry]:
                    for line in entry_data:
                        csv_output += ("%s, %s, %s\n"
                                       % (host_entry, entry_name, line))
            return csv_output

        if fmt == 'rst':
            rst_output = ""
            for host_entry in self.data.keys():
                rst_output += (
                    "%s\n%s\n%s\n\n"
                    % ("="*len(host_entry), host_entry, "="*len(host_entry))
                )

                for entry in self.data[host_entry]:
                    rst_output += "%s\n%s\n\n" % (entry[0], "-"*len(entry[0]))
                    for line in entry[1]:
                        rst_output += "%s\n" % line
                    rst_output += "\n"

            return rst_output
