#!/usr/bin/env python2

import os

TESTPLAN_RAW_FILE = os.environ.get("TESTPLAN_RAW_FILE", "test_plan.txt")
TESTPLAN_HTML_FILE = os.environ.get("TESTPLAN_HTML_FILE", "test_plan.html")
OPENSTACK_RELEASE = os.environ.get("OPENSTACK_RELEASE", "Ubuntu")

with open(TESTPLAN_RAW_FILE, "r") as data:
    text = [line.replace('\n', '').replace('\t', '')
            for line in data.readlines()]

skip_patterns = ["Snapshot", "groups =", "enabled =", "depends_on_groups =",
                 "depends_on =", "runs_after =", '/', '   *  *  *  Test Plan']

text = [line for line in text
        if not any(line.startswith(pattern) for pattern in skip_patterns)]

test_runs = '\n'.join(text).split("OPENSTACK_RELEASE")

with open(TESTPLAN_HTML_FILE, 'w') as myFile:
    myFile.write('<html>')
    myFile.write("<center style='font-size:26px'>")
    myFile.write('*  *  *  Test Plan  *  *  *')
    myFile.write("</center>")
    myFile.write("<br>")
    myFile.write("<br>")
    for test_run in test_runs[1:]:
        OPENSTACK_RELEASE = test_run.split('\n')[0].split('=')[1]
        test_plan = test_run.split('<function ')
        for line in test_plan[1:]:
            parts = line.split("\n")
            myFile.write("<p style='font-size:14px'>")
            myFile.write("name of the method is {}".format(parts[0].split()[0]))
            myFile.write("</p>")
            if len(parts) == 1:
                myFile.write("<hr>")
                continue
            if len(parts) > 1:
                myFile.write("<p style='font-size:16px; color:blue'>")
                myFile.write(parts[1])
                myFile.write(' ({})'.format(OPENSTACK_RELEASE))
                myFile.write("</p>")
                if len(parts) == 2:
                    myFile.write("<hr>")
                    continue
                if len(parts) > 2:
                    myFile.write("<p style='font-size:14px'>")
                    for j in range(2, len(parts)):
                        myFile.write(parts[j])
                        myFile.write("<br>")
                    myFile.write("</p>")
                    myFile.write("<hr>")
    myFile.write('</html>')
