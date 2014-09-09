#!/usr/bin/env python2.7

import jenkins
import yaml
from xml.dom import minidom
from xml.dom import Node
import xml
import re
import argparse
import formaters
import os
import logging

NonWhiteSpacePattern = re.compile('\S')


def isAllWhiteSpace(text):
    if NonWhiteSpacePattern.search(text):
        return 0
    return 1


def skipJob(name):
    skip_names = [
        'com.tikal.jenkins.plugins.multijob.MultiJobProject',
        'matrix-project',
    ]
    if name in skip_names:
        return True
    else:
        return False


def convertXml2Yaml(xmlString, name):
    doc = minidom.parseString(xmlString)
    root = doc.childNodes[0]

    # Convert the DOM tree into "YAML-able" data structures.
    out = []
    if skipJob(root.nodeName):
        d = {}
        d['job'] = {}
        d['job']['name'] = name
        d['job']['skipped'] = True
    else:
        d, u, o = convertXml2YamlAux(root)
        d['job']['name'] = name
    out.append(d)

    outStr = yaml.safe_dump(out, default_flow_style=False,
                            allow_unicode=True, encoding=False)
    return outStr


def convertXml2YamlAux(obj, saveEmpty=False, parentNode=None):

    obj.nodeName = formaters.rename(obj.nodeName, parentNode)

    if obj.getAttribute('plugin').split('@')[0] != '':
        plugin_name = obj.getAttribute('plugin').split('@')[0]
        obj.nodeName = formaters.rename(plugin_name, parentNode)

    if '__up__' in obj.nodeName:
        __up__ = True
        obj.nodeName = obj.nodeName.replace('__up__', '')
    else:
        __up__ = False
    objDict = {}
    objDict[obj.nodeName] = None

    text = []
    for child in obj.childNodes:
        if child.nodeType == Node.TEXT_NODE and \
                not isAllWhiteSpace(child.nodeValue):
            text.append(str(child.nodeValue))
    if text:
        textStr = "".join(text)
        try:
            if '.' in textStr:
                textStr = float(textStr)
            else:
                textStr = int(textStr)
        except ValueError:
            textStr = textStr
        if textStr == 'false':
            objDict[obj.nodeName] = False
        elif textStr == 'true':
            objDict[obj.nodeName] = True
        else:
            objDict[obj.nodeName] = textStr

    if formaters.listinside(obj.nodeName, parentNode):

        children = []
    else:
        children = {}

    for child in obj.childNodes:
        if child.nodeType == Node.ELEMENT_NODE:
            if (child.nodeName == 'scm'
                    and child.parentNode.nodeName in ('project', 'job')):

                new_child = child.cloneNode(deep=True)
                childNodes = []
                for i in child.childNodes:
                    childNodes.append(i)
                for child_in_child in childNodes:
                    deleted = child.removeChild(child_in_child)
                    deleted.unlink()
                child.appendChild(new_child)
                if child.hasAttributes():
                    attr_to_del = []
                    for i in range(child.attributes.length):
                        attr_to_del.append(child.attributes.item(i).name)
                    for i in attr_to_del:
                        child.removeAttribute(i)

            child_obj, up, oname = convertXml2YamlAux(child,
                                                      saveEmpty=False,
                                                      parentNode=obj)

            if child_obj[child.nodeName] is None:
                if saveEmpty is False:
                    continue
                child_obj[child.nodeName] = ""

            if type(children) == dict:
                if child.nodeName in child_obj:
                    children[child.nodeName] = child_obj[child.nodeName]
                else:
                    children[child.nodeName] = child_obj
            else:
                children.append(child_obj)

    if children:

        if obj.nodeName in children:
            objDict[obj.nodeName] = children[obj.nodeName]
        elif up is True:
            objDict[obj.nodeName] = children[oname]
        else:
            objDict[obj.nodeName] = children

    return objDict, __up__, obj.nodeName


def connect(url, user, password):
    return jenkins.Jenkins(url, user, password)


def get_params():
    args = argparse.ArgumentParser(description="Please put Jnkins server"
                                   " and credentials")

    args.add_argument("--url", help="Jankins server url", required=True,
                      type=str)
    args.add_argument("--user", help="User name", required=True,
                      type=str)
    args.add_argument("--passwd", help="Password", required=True,
                      type=str)
    args.add_argument("--job", help="dump jobs with selected name",
                      default=False, type=str)
    args.add_argument("--quite", help="Don't show messages", default=False,
                      type=bool)

    return args.parse_args()


def load_xml(s, job_name, use_cache=False):
    if use_cache is False:
        return s.get_job_config(job_name)
    else:
        if os.path.exists("xml_cache") is False:
            os.mkdir("xml_cache")
        if os.path.exists("%s/%s.xml" % ("xml_cache", job_name)):
            xml_file = open("%s/%s.xml" % ("xml_cache", job_name), "r")
            return xml_file.read()
        else:
            xml_file = open("%s/%s.xml" % ("xml_cache", job_name), "w")
            xml = s.get_job_config(job_name)
            xml_file.write(xml)
            return xml


def save_yaml(job_name, data):
    if os.path.exists("yaml") is False:
        os.mkdir("yaml")
    yaml_file = open("%s/%s.yml" % ("yaml", job_name), "w")
    yaml_file.write(data)
    yaml_file.close()


def makeLogger(level=logging.INFO):
    default_format = ('%(asctime)s - %(levelname)s %(filename)s:'
                      '%(lineno)d -- %(message)s')
    logging.basicConfig(level=logging.INFO,
                        format=default_format)
    logger = logging.getLogger(__name__)
    logger.setLevel(level)
    return logger


def main():
    run_params = get_params()
    if run_params.quite:
        log_level = logging.ERROR
    else:
        log_level = logging.INFO
    logger = makeLogger(log_level)
    logger.info("Connect to %s" % run_params.url)
    j = connect(
        run_params.url,
        run_params.user,
        run_params.passwd)
    if run_params.job is False:
        j_info = j.get_info()
        j_jobs = j_info['jobs']
        remain_jobs = len(j_jobs)
        logger.info("Jenkins have got %i" % len(j_jobs))
        jobs_configs = {}
        for job in j_jobs:
            logger.info(
                "Get %s job config. %i jobs remains" %
                (job['name'], remain_jobs))

            jobs_configs[job['name']] = load_xml(j, job['name'],
                                                 use_cache=True)
            remain_jobs -= 1

        remain_jobs = len(jobs_configs)
        logger.info("Total jobs in Jenkins: %i" % remain_jobs)
        for job_name in jobs_configs:
            logger.info(
                "Saving %s.yml. %i jobs remains" % (job_name, remain_jobs))

            try:
                yaml_str = convertXml2Yaml(jobs_configs[job_name], job_name)
            except Exception, e:
                if isinstance(e, xml.parsers.expat.ExpatError):
                    logging.error("XML config %s job have problem" % job_name)
                else:
                    raise

            save_yaml(job_name, yaml_str)
            remain_jobs -= 1
    else:
        job_config = j.get_job_config(run_params.job)
        logger.info("Got %s job config. " % (run_params.job))
        yaml_str = convertXml2Yaml(job_config, run_params.job)
        save_yaml(run_params.job, yaml_str)
        logger.info("Saved %s.yml" % run_params.job)

if __name__ == '__main__':
    main()
