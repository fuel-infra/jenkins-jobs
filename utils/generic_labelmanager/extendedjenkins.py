import json
import jenkins

from six.moves.http_client import BadStatusLine
from six.moves.urllib.error import HTTPError
from six.moves.urllib.request import Request

NODE_LIST = 'computer/api/json'


class Jenkins(jenkins.Jenkins):
    def get_nodes(self):
        try:
            nodes_data = json.loads(self.jenkins_open(Request(self.server +
                                                              NODE_LIST)))
            return [{'name': c["displayName"], 'offline': c["offline"]}
                    for c in nodes_data["computer"]]
        except (HTTPError, BadStatusLine):
            raise BadHTTPException("Error communicating with server[%s]"
                                   % self.server)
        except ValueError:
            raise JenkinsException("Could not parse JSON info for server[%s]"
                                   % self.server)
