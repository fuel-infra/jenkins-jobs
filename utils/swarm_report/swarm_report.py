#!/usr/bin/env python

from matplotlib import pyplot as plt

import argparse
import datetime
import json
import logging
import requests

logger = logging.getLogger(__name__)

def get_build_data(
        job_name,
        build_number="lastBuild",
        jenkins_url="http://jenkins-product.srt.mirantis.net:8080",
        params=None):

    build_url = "{0}/job/{1}/{2}/api/json".format(jenkins_url, job_name, build_number)
    logger.debug("Request build data: %s" % build_url)
    r = requests.get(build_url, params=params)
    build_data = json.loads(r.text)

    return build_data


def datetime_from_id(id):
    '''Convert Jenkins BUILD_ID to datetime'''
    return datetime.datetime.strptime(id, '%Y-%m-%d_%H-%M-%S')


def datetime_from_timestamp(timestamp):
    '''Convert timestamp (in seconds) to UTC time'''
    return datetime.datetime.utcfromtimestamp(timestamp/1000.0)


def datetime_to_timestamp(dt, epoch=datetime.datetime(1970,1,1)):
    '''Convert naive datetime to timestamp (in seconds)'''
    td = dt - epoch
    return (td.microseconds + (td.seconds + td.days * 86400) * 10**6) / 10**3


def timedelta_from_duration(duration):
    '''Convert Jenkins duration to timedelta object'''
    return datetime.timedelta(milliseconds=duration)


def set_hourly_x_ticks(plt):
    '''Set X-Axis to show hours'''
    xmin, xmax = plt.xlim()
    logger.debug("xmin: %s %s" % (xmin, datetime_from_timestamp(xmin)))

    ceiling_xmin = datetime_from_timestamp(xmin).replace(
        minute=0,
        second=0,
        microsecond=0
    ) + datetime.timedelta(hours=1)
    logger.debug("ceiling_xmin: %s" % ceiling_xmin)

    ceiling_xmin_timestamp = datetime_to_timestamp(ceiling_xmin)
    logger.debug("ceiling_xmin_timestamp: %s" % ceiling_xmin_timestamp)

    x_ticks = xrange(int(ceiling_xmin_timestamp), int(xmax), 1000*60*60)
    plt.xticks(
        x_ticks,
        map(lambda dt: datetime_from_timestamp(dt).strftime("%H:%M"), x_ticks),
        rotation='vertical',
    )

def result_to_color(result):
    if result == 'SUCCESS':
        return 'green'
    elif result == 'FAILURE':
        return 'red'
    elif result == 'ABORTED':
        return 'gray'
    else:
        return 'blue'

def plot_data(swarm_data, builds_data, nodes):
    # left: timestamp
    left = []
    # width: duration (if duration == 0 build is still running)
    width = []
    # bottom: slave_index * 11
    bottom = []
    # height: 10
    height = 10
    # bar names
    names = []
    # colors: red, green or gray, depending on build status
    color = []

    max_time = datetime_to_timestamp(datetime.datetime.now())

    for build_data in builds_data:
        left.append(build_data['timestamp'])
        if build_data['duration'] == 0:
            logger.debug("Build %s is still running" % build_data['url'])
            duration = max_time - build_data['timestamp']
            width.append(duration)
        else:
            width.append(build_data['duration'])
        bottom.append(nodes.index(build_data['builtOn']) * 11)
        names.append(build_data['url'].split('/')[-3].split(".")[-1])
        color.append(result_to_color(build_data['result']))

    plt.barh(bottom, width, height, left, color=color, alpha=0.2, linewidth=0.1)
    plt.yticks(
        xrange(5, len(nodes)*11, 11),
        map(lambda node: node.replace("mirantis.net",".."), nodes),
        fontsize=6,
    )

    set_hourly_x_ticks(plt)

    plt.xlabel('Time')
    plt.title('Swarm run #%s - %s' %
              (swarm_data['number'], datetime_from_id(swarm_data['id']))
    )

    # Set labels for every bar
    counters = [0] * len(nodes)
    for i in xrange(len(names)):
        l, b, name = left[i], bottom[i], names[i]
        plt.text(
            l + 50000,
            b + 3*counters[b/11],
            name,
            horizontalalignment='left',
            verticalalignment='bottom',
            fontsize=4,
            rotation=10
        )
        counters[b/11] = (counters[b/11] + 1) % 3

    return plt

def fetch_tests_data(job_name='6.1.swarm.runner', build_number='lastBuild'):

    swarm_data = get_build_data(job_name, build_number=build_number)
    system_tests = [
        item for item in swarm_data['subBuilds']
        if item['phaseName'] == 'Run system tests'
    ]

    builds_data = []

    for build in system_tests:
        builds_data.append(
            get_build_data(
                build['jobName'],
                build['buildNumber'],
                params= {'tree': 'url,id,builtOn,timestamp,duration,result'},
            )
        )

    nodes = sorted(
        list(
            set(
                [item['builtOn'] for item in builds_data]
            )
        )
    )

    return swarm_data, builds_data, nodes


def main():

    logger.addHandler(logging.StreamHandler())

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description='''Plot how nodes were used by swarm tests run'''
    )
    parser.add_argument("-v", "--verbose", help="Add debug output",
                        action="store_true")

    parser.add_argument("-j", "--job-name", help="Runner job",
                        default='6.1.swarm.runner',
    )

    parser.add_argument("-N", "--number", help="Build number for runner build",
                        default="lastBuild",
                        metavar="NUMBER",
                        dest="build_number",
    )

    parser.add_argument("-o", "--output", help="Filename to which result is going to be saved",
                        default='{build_id}.{number}.svg',
                        dest="filename",
                        metavar="FILENAME",
    )

    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    logger.debug("Arguments: %s" % args)

    swarm_data, builds_data, nodes = fetch_tests_data(args.job_name, args.build_number)
    plt = plot_data(swarm_data, builds_data, nodes)

    plt.savefig(args.filename.format(
        build_id=swarm_data['id'],
        number=swarm_data['number'])
    )

if __name__ == '__main__':
    main()
