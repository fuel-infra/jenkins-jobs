Structure
=========

``conf/jenkins-data.yaml``

  List of Jenkins plugins required to run jobs defined in this repo
  and other general Jenkins requirements.

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

  Common templates. To use templates make symlink from corresponding
  Jenkins master folder.

  The following objects can be used in templates definition:

    - 'main' repository,
    - 'main' trigger.

  They should be defined for every Jenkins master in the corresponding
  ``servers/<jenkins-master-id>/global.yaml`` file.

``tox.ini``

  Tox tests configuration. Running command::

    tox -v <jenkins-master-id>

  produces all XML files for specified Jenkins master and puts them
  into ``<tox_env>/test_output`` folder.
