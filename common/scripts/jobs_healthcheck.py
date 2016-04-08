#!/usr/bin/python

from datetime import datetime
import json
import os
import re
import sys
import urllib


class IncorrectColumnNumberError(Exception):
    pass


class HTMLStatusReport():

    def __init__(self, jenkins_url, jenkins_view):
        # Map build results to CSS classes
        self.trclasses = {
            "SUCCESS": "success",
            "FAILURE": "danger",
            "ABORTED": "danger",
            None: "warning"
        }
        self.styles = '''<head>
<link rel="stylesheet" href="https://static.fuel-infra.org/bootstrap/3.3.4/css/bootstrap.min.css"/>
</head>
'''
        self.a_regexp_str = r'<a\s+href="(.*)"\s*>'
        self.a_regexp = re.compile(self.a_regexp_str, re.M)
        self.columns_num = 0
        self.columns_data = []
        self.criterion = None
        self.jobs_list = []
        self.data_file = "out.json"
        self.headers = []
        self.report_file = "status.html"
        self.url = jenkins_url
        self.view = jenkins_view
        self.tree_query = "tree=jobs[name,url,description,buildable,"\
            "builds[actions[parameters[*],causes[*]],building,description,"\
            "id,result,timestamp,url]]"
        self.view_url = "{0}view/{1}/api/json?pretty=true&{2}".format(
            self.url, self.view, self.tree_query)

    def setHeaders(self, headers_str):
        self.headers = headers_str.split(",")
        if self.columns_num == 0:
            self.columns_num = len(self.headers)
        elif len(self.headers) != self.columns_num:
            raise IncorrectColumnNumberError

    def setColumnsData(self, columns_data):
        self.columns_data = columns_data.split(",")
        if self.columns_num == 0:
            self.columns_num = len(self.columns_data)
        elif len(self.columns_data) != self.columns_num:
            raise IncorrectColumnNumberError

    def setBuildSelectionCriterion(self, criterion):
        # Parse criterion to be able to use logical expressions
        # with AND and OR operators
        op = None
        if "&&" in criterion:
            op = "and"
            exprs = criterion.split("&&")
            expr_count = 2
        elif "||" in criterion:
            op = "or"
            exprs = criterion.split("||")
            expr_count = 2
        else:
            exprs = [criterion]
            expr_count = 1

        self.criterion = {"op": op}
        for expr_num in xrange(expr_count):
            expr_name = "expr{0}".format(expr_num)
            c_list = exprs[expr_num].split("=")
            self.criterion[expr_name] = (
                c_list[0], None if c_list[1] == "None" else c_list[1])

    def getData(self):
        urllib.urlretrieve(self.view_url, self.data_file)
        self.parse()

    def getParamValue(self, data_dict, fullname):
        # All data from 'causes' object and 'parameters' array of Jenkins JSON
        # is accessible via path-like form, e.g. 'CAUSES/param_name'
        param_list = fullname.split("/")
        value = data_dict.get(param_list[0])
        if value is not None:
            for part in param_list[1:]:
                value = value.get(part)
        return value

    def check_condition(self, expr_name, job_dict):
        # Check if simple criterion is satisfied
        c_key, c_val = self.criterion[expr_name]
        if "/" in c_key:
            val = self.getParamValue(job_dict, c_key)
        else:
            val = job_dict[c_key]
        return True if val == c_val else False

    def check_build(self, job_dict):
        # Top function to check for build selection criterion.
        # Here logical expressions are treated
        if self.criterion is None:
            return True
        elif self.criterion["op"] is None:
            return self.check_condition("expr0", job_dict)
        else:
            val0 = self.check_condition("expr0", job_dict)
            val1 = self.check_condition("expr1", job_dict)
            result = None
            exec "result = {0} {1} {2}".format(
                val0, self.criterion["op"], val1)
            return result

    def parse_parameters(self, objects_array):
        # Create python dict from JSON array of objects with name/value keys
        result = {}
        for param in objects_array:
            result[param["name"]] = param["value"]
        return result

    def parse(self):
        with open(self.data_file, "r") as fd:
            obj = json.load(fd)
        # Take only buildable (enabled) jobs
        for job in (i for i in obj["jobs"] if i["buildable"]):
            job_record = {}
            job_record["NAME"] = job["name"]
            job_record["DESCRIPTION"] = job["description"]
            job_record["URL"] = job["url"]
            # Work with finished builds only (not building)
            for build in (j for j in job["builds"] if not j["building"]):
                build_record = {}
                build_record["RESULT"] = build["result"]
                build_record["BUILD_URL"] = build["url"]
                build_record["TIMESTAMP"] = datetime.utcfromtimestamp(
                    int(build["timestamp"]/1000))
                build_record["BUILD_ID"] = build["id"]
                build_record["BUILD_DESCRIPTION"] = build["description"]
                for item in build["actions"]:
                    if "parameters" in item:
                        build_record["PARAMETERS"] = \
                            self.parse_parameters(item["parameters"])
                    elif "causes" in item:
                        build_record["CAUSES"] = item["causes"][0]
                # Check the selected build for the criterion and
                # if the criterion is satisfied update job data with build one
                # and break the cycle
                if self.check_build(build_record):
                    job_record.update(build_record)
                    break
            self.jobs_list.append(job_record)

    def createTableHeaders(self):
        header_html = "<thead><tr>"
        for item in xrange(len(self.headers)):
            header_html += "<th>{{{0}}}</th>".format(item)
        header_html += "</tr></thead>\n"
        return header_html

    def cellData(self, data_dict, column):
        cell_html = ''
        if column == "NAME":
            if data_dict.get("BUILD_URL") is None:
                url = data_dict["URL"]
            else:
                url = data_dict["BUILD_URL"]
            cell_html += '<td><a href="{0}" target="_blank" ' \
                'data-toggle="tooltip" title="Build #{2}">{1}' \
                '</a></td>'.format(
                    url, data_dict["NAME"], data_dict.get("BUILD_ID"))
        elif column == "BUILD_DESCRIPTION" and \
                data_dict.get(column) is not None:
            desc = self.a_regexp.sub(r'<a href="\1" target="_blank">',
                                     data_dict.get(column))
            cell_html += '<td>{0}</td>'.format(desc)
        elif "/" in column:
            cell_html += '<td>{0}</td>'.format(
                self.getParamValue(data_dict, column))
        else:
            cell_html += '<td>{0}</td>'.format(data_dict.get(column))
        return cell_html

    def dumpReport(self):
        success = True
        with open(self.report_file, "w") as report:
            report.write('<body>\n')
            report.write(self.styles)
            report.write('<div style="overflow-x:auto;">')
            report.write('<table  class="table table-hover">\n')
            report.write(self.createTableHeaders().format(*self.headers))
            report.write('<tbody>\n')
            for job in self.jobs_list:
                if job.get('RESULT') in ['FAILURE', 'ABORTED']:
                    success = False
                line = '<tr class="{0}">'.format(
                    self.trclasses[job.get('RESULT')])
                for column in self.columns_data:
                    line += self.cellData(job, column)
                line += '</tr>\n'
                report.write(line)
            report.write('<caption align="bottom">Created at {0}</caption>\n'.format(
                datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")))
            report.write('</tbody></table></div></body>\n')
        return success


def main():
    jenkins_url = os.environ["JENKINS_URL"]
    jenkins_view = os.environ["JENKINS_VIEW"]
    criterion = os.environ["BUILD_SELECTION_CRITERION"]
    table_headers = os.environ["TABLE_HEADERS"]
    table_columns = os.environ["TABLE_COLUMNS"]
    status = HTMLStatusReport(jenkins_url, jenkins_view)
    status.setHeaders(table_headers)
    status.setColumnsData(table_columns)
    status.setBuildSelectionCriterion(criterion)
    status.getData()
    status = status.dumpReport()
    if not status:
        sys.exit(1)

if __name__ == '__main__':
    main()
