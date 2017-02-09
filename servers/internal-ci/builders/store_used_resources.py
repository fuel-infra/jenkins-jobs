#!/usr/bin/env python

"""
This script gather and store statistics information about used
resources on jenkins slaves during builds.
"""

import datetime
import jenkins
import json
import logging
import os
import requests
import sqlalchemy
import sqlalchemy.exc
import sqlalchemy.ext.declarative
import sqlalchemy.orm

import urlparse

assert os.getenv("STATS_MYSQL_USERNAME")
assert os.getenv("STATS_MYSQL_PASSWORD")
assert os.getenv("STATS_MYSQL_HOST")
assert os.getenv("ZABBIX_USERNAME")
assert os.getenv("ZABBIX_PASSWORD")

ZABBIX_URL = os.getenv("ZABBIX_URL", "https://monitoring.infra.mirantis.net")
JENKINS_SERVERS = os.getenv("JENKINS_SERVERS", "").split(" ")
for url in JENKINS_SERVERS:
    assert urlparse.urlparse(url).netloc, "Can't parse jenkins server url: " \
                                          "'{url}'".format(url=url)

# Skip build if it's older than this
BUILD_KEEP_DAYS = int(os.getenv("BUILD_KEEP_DAYS", 2))
# Skip build if it took less than this
BUILD_SKIP_SECONDS = int(os.getenv("BUILD_SKIP_SECONDS", 120))

GB = 1024 * 1024 * 1024

logging.basicConfig(level=logging.WARNING)
Base = sqlalchemy.ext.declarative.declarative_base()


class Server(Base):
    """Describes jenkins server table"""
    __tablename__ = "servers"
    Id = sqlalchemy.Column(sqlalchemy.Integer, primary_key=True,
                           autoincrement=True)
    Name = sqlalchemy.Column(sqlalchemy.String(255), unique=True,
                             nullable=False)


class Job(Base):
    """Describes jenkins job table"""
    __tablename__ = "jobs"
    Id = sqlalchemy.Column(sqlalchemy.Integer, primary_key=True,
                           autoincrement=True)
    Name = sqlalchemy.Column(sqlalchemy.String(255), nullable=False)
    ServerId = sqlalchemy.Column(sqlalchemy.Integer,
                                 sqlalchemy.ForeignKey("servers.Id"),
                                 nullable=False)
    Server = sqlalchemy.orm.relationship("Server")


class Build(Base):
    """Describes jenkins build table"""
    __tablename__ = "builds"
    Id = sqlalchemy.Column(sqlalchemy.Integer, primary_key=True,
                           autoincrement=True)
    BuildNumber = sqlalchemy.Column(sqlalchemy.Integer, nullable=False)
    TsFrom = sqlalchemy.Column(sqlalchemy.DateTime, nullable=False)
    TsTill = sqlalchemy.Column(sqlalchemy.DateTime, nullable=False)
    BuiltOn = sqlalchemy.Column(sqlalchemy.String(255), nullable=False)
    IsFailed = sqlalchemy.Column(sqlalchemy.Boolean, nullable=False)
    JobId = sqlalchemy.Column(sqlalchemy.Integer,
                              sqlalchemy.ForeignKey("jobs.Id"), nullable=False)
    Job = sqlalchemy.orm.relationship("Job")


class Item(Base):
    """Describes zabbix items table"""
    __tablename__ = "items"
    Id = sqlalchemy.Column(sqlalchemy.Integer, primary_key=True,
                           autoincrement=True)
    Name = sqlalchemy.Column(sqlalchemy.String(255), unique=True,
                             nullable=False)
    Dividor = sqlalchemy.Column(sqlalchemy.Float, default=1.0, nullable=False)
    Multiplicator = sqlalchemy.Column(sqlalchemy.Float, default=1.0,
                                      nullable=False)


class Value(Base):
    """Describes zabbix items values table"""
    __tablename__ = "item_values"
    Id = sqlalchemy.Column(sqlalchemy.Integer, primary_key=True,
                           autoincrement=True)
    ItemId = sqlalchemy.Column(sqlalchemy.Integer,
                               sqlalchemy.ForeignKey("items.Id"),
                               nullable=False)
    BuildId = sqlalchemy.Column(sqlalchemy.Integer,
                                sqlalchemy.ForeignKey("builds.Id"),
                                nullable=False)
    Vcount = sqlalchemy.Column(sqlalchemy.Integer, nullable=False)
    Vfirst = sqlalchemy.Column(sqlalchemy.Float, nullable=False)
    Vlast = sqlalchemy.Column(sqlalchemy.Float, nullable=False)
    Vmin = sqlalchemy.Column(sqlalchemy.Float, nullable=False)
    Vmax = sqlalchemy.Column(sqlalchemy.Float, nullable=False)
    Vavg = sqlalchemy.Column(sqlalchemy.Float, nullable=False)
    Item = sqlalchemy.orm.relationship("Item")
    Build = sqlalchemy.orm.relationship("Build")


sqlalchemy.Index('idx_jobs_name_serverid', Job.Name, Job.ServerId, unique=True)
sqlalchemy.Index('idx_buildnumber_jobid', Build.BuildNumber, Build.JobId,
                 unique=True)


class ZabbixAPI:
    """Helper class to work with zabbix jsonrpc api"""

    def __init__(self, server, username, password, timeout=None):
        """Initialize session and trying to authenticate in api"""
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json-rpc',
            'User-Agent': 'python/pyzabbix',
            'Cache-Control': 'no-cache'
        })
        self.id = 0
        self.timeout = timeout
        self.url = server + '/api_jsonrpc.php'
        self.auth = ''
        self.auth = self.do_request("user.login",
                                    {"user": username,
                                     "password": password})['result']

    def do_request(self, method, params=None):
        """
        Request to zabbix api

        :param method: method name to request
        :type method: str
        :param params: method parameters
        :type params: dict
        :return:
        """
        request_json = {
            'jsonrpc': '2.0',
            'method': method,
            'params': params or {},
            'id': self.id
        }
        if self.auth:
            request_json['auth'] = self.auth
        response = self.session.post(
            self.url,
            data=json.dumps(request_json),
            timeout=self.timeout
        )
        response.raise_for_status()
        if not len(response.text):
            raise ValueError("Received empty response")
        try:
            response_json = json.loads(response.text)
        except ValueError:
            raise ValueError(
                "Unable to parse json: {msg}".format(msg=response.text))
        self.id += 1
        if 'error' in response_json:
            if 'data' not in response_json['error']:
                response_json['error']['data'] = "No data"
            msg = "Error {code}: {message}, {data}".format(
                code=response_json['error']['code'],
                message=response_json['error']['message'],
                data=response_json['error']['data']
            )
            raise ValueError(msg, response_json['error']['code'])
        return response_json


class StoreJobsStats:
    """
    Gather and store resources usage for builds
    """

    def __init__(self):
        """
        Initialize database connection and zabbix api connection
        """
        self.servers = map(jenkins.Jenkins, JENKINS_SERVERS)
        self.db_eng = sqlalchemy.create_engine(
            "mysql+mysqldb://{user}:{passwd}@{host}:{port}/{db}".format(
                host=os.getenv("STATS_MYSQL_HOST", "127.0.0.1"),
                port=int(os.getenv("STATS_MYSQL_PORT", 3306)),
                user=os.getenv("STATS_MYSQL_USERNAME", "root"),
                passwd=os.getenv("STATS_MYSQL_PASSWORD", ""),
                db=os.getenv("STATS_MYSQL_DB", "jobs_stats")
            ))
        Base.metadata.create_all(self.db_eng)
        self.Session = sqlalchemy.orm.sessionmaker(bind=self.db_eng)
        self.ses = self.Session()
        self.zapi = ZabbixAPI(ZABBIX_URL,
                              username=os.getenv("ZABBIX_USERNAME"),
                              password=os.getenv("ZABBIX_PASSWORD"))
        self.zapi.timeout = 10
        self.items = {
            "vfs.fs.size[/,used]": [GB, 1],
            "vfs.fs.size[/,free]": [GB, 1],
            "vm.memory.size[available]": [GB, 1],
            "system.cpu.load[percpu,avg1]": [1, 100],
            "system.cpu.load[percpu,avg5]": [1, 100],
            "system.cpu.load[percpu,avg15]": [1, 100]
        }

    def start(self):
        """Start a loop"""
        map(self.do_a_job, self.servers)

    def _add_or_get(self, model, limitargs=list(), **kwargs):
        """
        Trying to get existing or create new object in database

        :param model: db table
        :type model: sqlalchemy model
        :param limitargs:  list of column names, which is enough to check
        uniqueness
        :type limitargs: [str]
        :param kwargs: db table columns
        :return: database object instance and True if it was exists before
        :rtype: (DBInstance, bool)
        """
        query_args = kwargs
        if len(limitargs):
            query_args = {k: kwargs[k] for k in limitargs}
        res = self.ses.query(model).filter_by(**query_args).first()
        if res:
            return res, True
        instance = model(**kwargs)
        self.ses.add(instance)
        self.ses.commit()
        return instance, False

    def add_server(self, jenkins_url):
        """
        Add new or get server from database

        :param jenkins_url: url for jenkins server
        :type jenkins_url: str
        :return: (Server, exists before?)
        :rtype: (Server, bool)
        """
        return self._add_or_get(Server, Name=jenkins_url)

    def add_job(self, server, job_name):
        """
        Add new or get existing job from database

        :param server: jenkins server object
        :type server: Server
        :param job_name: name of a job
        :type job_name: str
        :return: (Job, exists before?)
        :rtype: (Job, bool)
        """
        return self._add_or_get(Job, Name=job_name, ServerId=server.Id)

    def add_build(self, job, number, ts_from, ts_till, built_on, failed):
        """
        Add new or get existing build from database

        :param job: job which build corresponds to
        :type job: Job
        :param number: build number from jenkins
        :type number: int
        :param ts_from: time when build was started
        :type ts_from: datetime.datetime
        :param ts_till: time when build was stopped
        :type ts_till: datetime.datetime
        :param built_on: slave hostname
        :type built_on: str
        :param failed: True if build was failed
        :type failed: bool
        :return: (Build, exists before?)
        :rtype: (Build, bool)
        """
        # We should use limitargs here because sometimes we have different ts_*
        # for the same build. For example if build is in progress.
        return self._add_or_get(Build,
                                limitargs=["BuildNumber", "JobId"],
                                BuildNumber=number,
                                TsFrom=ts_from,
                                TsTill=ts_till,
                                BuiltOn=built_on,
                                IsFailed=failed,
                                JobId=job.Id)

    def add_item(self, name, divisor=1, multi=1):
        """
        Add new or get existing zabbix item from database

        :param name: item name
        :type name: str
        :param divisor: number if we need to divide values when displaying
        :type divisor: float
        :param multi: number to multiple values when displaying
        :type multi: float
        :return:
        """
        return self._add_or_get(Item, limitargs=["Name"],
                                Name=name, Dividor=divisor,
                                Multiplicator=multi)

    def add_value(self, build, item, vcount, vfirst, vlast, vmin, vmax, vavg):
        """
        Add new stats for specific item during build
        or get existing from database

        :param build: build, which this value corresponds to
        :type build: Build
        :param item: item, which this value corresponds to
        :type item: Item
        :param vcount: count of values got from zabbix
        :type vcount: int
        :param vfirst: first value got from zabbix
        :type vfirst: float
        :param vlast: last value got from zabbix
        :type vlast: float
        :param vmin: minimum value got from zabbix
        :type vmin: float
        :param vmax: maximum value got from zabbix
        :type vmax: float
        :param vavg: average value got from zabbix
        :type vavg: float
        :return: (Value, exists before?)
        :rtype: (Value, bool)
        """
        return self._add_or_get(Value,
                                ItemId=item.Id,
                                BuildId=build.Id,
                                Vcount=vcount, Vfirst=vfirst, Vlast=vlast,
                                Vmin=vmin, Vmax=vmax, Vavg=vavg)

    def ask_zabbix(self, hostname, item_name, ts_from, ts_till):
        """
        Perform queries to zabbix api for special build

        :param hostname: hostname of a jenkins slave used for build
        :param item_name: name of a zabbix item
        :param ts_from: unix timestamp when job was started
        :param ts_till: unix timestamp when job was finished
        :return:
        """
        host_params = {
            "output": "extend",
            "filter": {"host": hostname}
        }
        try:
            host_id = self.zapi.do_request("host.get",
                                           host_params)['result'][0]['hostid']
        except IndexError:
            logging.error("Can't find host_id for {host}".format(host=hostname))
            return
        item_params = {
            "output": "extend",
            "hostids": host_id,
            "filter": {
                "key_": item_name,
            }
        }
        try:
            item = self.zapi.do_request("item.get", item_params)['result'][0]
        except IndexError:
            logging.error(
                "Can't find item_id for {item} on host "
                "{host}({host_id})".format(item=item_name, host=hostname,
                                           host_id=host_id))
            return
        item_id = item["itemid"]
        item_value_type = item["value_type"]
        history_params = {
            "itemids": item_id,
            "hostids": host_id,
            "history": item_value_type,
            "sortfield": "clock",
            "output": "extend",
            "time_from": ts_from,
            "time_till": ts_till
        }
        res = self.zapi.do_request("history.get", history_params)
        values = map(lambda r: float(r['value']), res['result'])
        v_count = len(values)
        took = datetime.datetime.fromtimestamp(
            ts_till) - datetime.datetime.fromtimestamp(ts_from)
        if not v_count:
            logging.warning(
                "There is no {item}({itemid}) for host: {host}({hostid}) "
                "from: {tsfrom}, till: {tstill}, took: {took}".format(
                    item=item_name,
                    itemid=item_id,
                    host=hostname,
                    hostid=host_id,
                    tsfrom=ts_from,
                    tstill=ts_till,
                    took=took))
            return
        v_first = values[0]
        v_last = values[-1]
        v_min = min(values)
        v_max = max(values)
        v_avg = sum(values) / v_count
        return {
            "first": v_first,
            "last": v_last,
            "min": v_min,
            "max": v_max,
            "avg": v_avg,
            "count": v_count}

    def do_a_job(self, jenkins_server):
        """
        Gather and store statistics.

        SKip build and all older for this job:
            - if it was finished more than BUILD_KEEP_DAYS ago
            - if it's already present in database
        :param jenkins_server: jenkins server from which we checking jobs
        :type jenkins_server: jenkins.Jenkins
        """
        jenkins_url = urlparse.urlparse(jenkins_server.server).hostname
        db_server, _ = self.add_server(jenkins_url)
        for job in jenkins_server.get_jobs():
            job_name = job['name']
            db_job, _ = self.add_job(db_server, job_name)
            job_info = jenkins_server.get_job_info(job_name)
            build_ids = sorted(
                list(
                    map(
                        lambda b: b['number'], job_info['builds'])),
                reverse=True)
            for build_id in build_ids:
                logging.info(
                    "Checking {job} {build} on jenkins {jenkins}".format(
                        job=job_name, build=build_id, jenkins=jenkins_url))
                jenkins_build = jenkins_server.get_build_info(job_name,
                                                              build_id)
                ts_from = jenkins_build['timestamp'] / 1000
                ts_till = ts_from + jenkins_build['duration'] / 1000
                host = jenkins_build['builtOn']
                is_failed = jenkins_build['result'] == 'FAILURE'
                dt_now = datetime.datetime.now()
                dt_till = datetime.datetime.fromtimestamp(ts_till)
                stopped_dt = dt_now - dt_till
                if stopped_dt.days > BUILD_KEEP_DAYS:
                    logging.warning(
                        "Build {name}, {id} from {host} is very old. "
                        "Skip all other.".format(name=job_name,
                                                 id=build_id,
                                                 host=jenkins_url))
                    break
                db_build, db_build_exists = self.add_build(
                    db_job,
                    number=build_id,
                    ts_from=datetime.datetime.fromtimestamp(ts_from),
                    ts_till=datetime.datetime.fromtimestamp(ts_till),
                    built_on=host,
                    failed=is_failed
                )
                if db_build_exists:
                    logging.warning(
                        "Build  {name}, {id} from {host} already in db."
                        " Skip all other.".format(name=job_name,
                                                  id=build_id,
                                                  host=jenkins_url))
                    break
                if ts_till - ts_from <= BUILD_SKIP_SECONDS:
                    logging.info(
                        "Build {job}, {build} took less than {skip} seconds. "
                        "Skipping.".format(job=job_name, build=build_id,
                                           skip=BUILD_SKIP_SECONDS))
                    break
                for item_name in self.items:
                    db_item, _ = self.add_item(
                        name=item_name,
                        divisor=self.items[item_name][0],
                        multi=self.items[item_name][1]
                    )
                    zabbix = self.ask_zabbix(host, item_name, ts_from, ts_till)
                    if zabbix:
                        self.add_value(
                            db_build,
                            db_item,
                            zabbix["count"],
                            zabbix["first"],
                            zabbix["last"],
                            zabbix["min"],
                            zabbix["max"],
                            zabbix["avg"],
                        )
        logging.info("Server {url} done".format(url=jenkins_url))


if __name__ == "__main__":
    jobs_stats = StoreJobsStats()
    jobs_stats.start()
