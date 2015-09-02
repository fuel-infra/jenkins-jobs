from contextlib import contextmanager as _contextmanager
from fabric import state

from fabric.api import cd
from fabric.api import env
from fabric.api import execute
from fabric.api import prefix
from fabric.api import run
from fabric.api import runs_once
from fabric.api import task

from utils import Jenkins, Result

state.output['running'] = False
state.output['stderr'] = False
state.output['warnings'] = False

env.result = Result()
env.warn_only = True


# Virtualenv support

@_contextmanager
def venv():
    venv_path = "/home/jenkins/venv-nailgun-tests/"
    with cd(venv_path):
        with prefix("source " + venv_path + "bin/activate"):
            yield


@_contextmanager
def venv29():
    venv_path = "/home/jenkins/venv-nailgun-tests-2.9/"
    with cd(venv_path):
        with prefix("source " + venv_path + "bin/activate"):
            yield


# Define hosts

@task
def jenkins_product_ci(label=None, names=None):

    J = Jenkins('http://jenkins-product.srt.mirantis.net')
    env.hosts = J.list_nodes(label, names)

    print "\n".join(env.hosts)

@task
def product_ci(label=None, names=None):

    J = Jenkins('https://product-ci.infra.mirantis.net')
    env.hosts = J.list_nodes(label, names)
    print "\n".join(env.hosts)

@task
def old_stable_ci(label=None, names=None):

    J = Jenkins('https://old-stable-ci.infra.mirantis.net')
    env.hosts = J.list_nodes(label, names)
    print "\n".join(env.hosts)

@task
def fuel_ci(label=None, names=None):

    J = Jenkins('https://ci.fuel-infra.org')
    env.hosts = J.list_nodes(label, names)

    print "\n".join(env.hosts)

@task
def osci_ci(label=None, names=None):

    J = Jenkins('http://osci-jenkins.srt.mirantis.net:8080')
    env.hosts = J.list_nodes(label, names)

    print "\n".join(env.hosts)

@task
def infra_ci(label=None, names=None):

    J = Jenkins('https://infra-ci.fuel-infra.org')
    env.hosts = J.list_nodes(label, names)

    print "\n".join(env.hosts)

@task
def packaging_ci(label=None, names=None):

    J = Jenkins('https://packaging-ci.infra.mirantis.net')
    env.hosts = J.list_nodes(label, names)

    print "\n".join(env.hosts)

@task
def patching_ci(label=None, names=None):

    J = Jenkins('https://patching-ci.infra.mirantis.net')
    env.hosts = J.list_nodes(label, names)

    print "\n".join(env.hosts)


# Tasks

@task
def dos_py(command="version"):

    with venv():
        data = run("dos.py " + command)

    result_entry = (
        " ".join(["dos.py", command]),
        map(str.strip, data.split("\n"))
    )
    env.result.add_entry(env.host, result_entry)


@task
def dos_py_29(command="version"):

    with venv29():
        data = run("dos.py " + command)

    result_entry = (
        " ".join(["dos.py", command, "29"]),
        map(str.strip, data.split("\n"))
    )
    env.result.add_entry(env.host, result_entry)


@task
def dos_clean(string):
    with venv():
        run('for env in `dos.py list | grep "%s"`;'
            'do echo $env && dos.py erase $env; done' % string)


@task
def dos_clean_29(string):
    with venv29():
        run('for env in `dos.py list | grep "%s"`;'
            'do echo $env && dos.py erase $env; done' % string)


@task
def virsh(command="list"):
    data = run("virsh " + command)
    result_entry = (
        " ".join(["virsh", command]),
        map(str.strip, data.split("\n"))
    )
    env.result.add_entry(env.host, result_entry)


@task
def ml2_check():
    data = run("cat /proc/sys/net/bridge/bridge-nf-call-iptables")
    result_entry = (
        "bridge-nf-call-iptables",
        map(str.strip, data.split("\n"))
    )
    env.result.add_entry(env.host, result_entry)

@task
def hw_check():
    cpu = run("nproc").strip()
    memory = run('grep "^MemTotal:" /proc/meminfo').split()[-2]
    result_entry = (
        "hw_check",
        ("{0}:{1}".format(cpu, int(memory)/1024/1024+1),)
    )
    env.result.add_entry(env.host, result_entry)


@task
@runs_once
def stats(venvs=True, envs=True):
    execute(dos_py, "list")
    execute(dos_py_29, "list")
    execute(dos_py)
    execute(dos_py_29)
    execute(virsh)
    execute(ml2_check)

@task
@runs_once
def publish(fmt='txt', filename=None):

    if filename:
        with open(filename, 'w') as f:
            f.write(env.result.formatted(fmt))
    else:
        print env.result.formatted(fmt)
