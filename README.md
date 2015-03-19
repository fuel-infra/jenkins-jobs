Repo Structure
==============

``conf/jenkins-data.yaml``

  List of Jenkins plugins required to run jobs defined in this repo
  and other general Jenkins requirements.
  Please note that 'jenkins-jobs test' call requires list of plugins
  either from Jenkins instance (in .ini file) or provided via
  '-p' option.

``conf/jenkins_job.ini.example``

  Example config file. Can be used as it is to run tests, when tests
  don't require Jenkins connection.

``conf/requirements.txt``

  Python requirements to run tox tests.

``servers/<jenkins-master-id>/``

  Every Jenkins Master instance should have its own dedicated
  folder. For example, ``servers/pkgs-ci/`` folder corresponds to
  pkgs-ci.jenkins.org.

``common/``

  Common templates.

  The following objects can be used in templates definition:

    - 'main' repository,
    - 'main' trigger.

  They should be defined for every Jenkins master in the corresponding
  ``servers/<jenkins-master-id>/global.yaml`` file.

``tox.ini``

  Tox tests configuration. Running command::

    tox -v

  produces all XML files for all Jenkins instances and puts them
  into ``./output/<jenkins-master-id`` folder.

``utils/dump_plugins.py``

  Dumps jenkins-job-builder compatible list of plugins
  from Jenkins instance.



Review Checklist
================

Simple CI jobs
--------------

* Job description exists
* Concurrent and throttle parameters are set
* Empty run with timer is configured
* Job is tested for all supported stable branches
* Job uses its own label
