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

``servers/fuel-ci/``

https://ci.fuel-infra.org/

``servers/infra-ci/``

???

``servers/jenkins-product-ci/``

http://jenkins-product.srt.mirantis.net:8080/

``servers/new-product-ci/``

https://product-ci.infra.mirantis.net/

``servers/old-stable-ci/``

???

``servers/openstack-ci/``

http://osci-jenkins.srt.mirantis.net:8080/

``servers/patching-ci/``

???

``servers/pkgs-ci/``

https://packaging-ci.infra.mirantis.net/

``servers/plugins-ci/``

???

``servers/scale-ci/``

???

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

  Dumps jenkins-job-builder compatible list of plugins from Jenkins
  instance.

``utils/gerritsetup.groovy``

  Standalone util to configure Gerrit Trigger plugin on a Jenkins
  Master. Allows to create a new gerrit server with preconfigured
  settings, along with adjusting gerrit's global settings.

``utils/generic_labelmanager/labelmanager.py``

  Tool for managing Jenkins Slave labels. Allows to add, remove or restore
  labels from a specific nodes or randomly selected.

Code Guidelines
===============

* Job description exists
* Ownership is specified
* Concurrent and throttle parameters are set properly

Shell-scripts
-------------

* Use::

    #!/bin/bash

    set -ex

  whenever possible. In case ``set -ex`` can not be used, leave a
  comment in the script.

* Use ``source`` command instead of ``dot``

* Use ``$(command)`` instead of backticks

* Follow usual BASH coding-style, for example use ``${SOME_VAR}``
  instead of ``$SOME_VAR`` whenever possible. See include-raw section
  for exceptions.

include-raw vs include-raw-escape
---------------------------------

NOTE: As include-raw-escape does unnecessary escaping when used in job
configuration, it should be used only in job templates.

When script/text file is included into *job* config:

   - use ``!include-raw``

When script/text file is included into *job-template* config:

   - use ``!include-raw-escape``

When script/text file is included into *job-template* config and you
need to pass certain parameters from the template to it, consider
injecting variables via env-inject plugin. If it is not possible:

   - use ``!include-raw``
   - in BASH scripts:

     - use curly brackets only for template parameters,
     - add a comment with list of parameters, which are going to be
       substituted from template variables

Simple Fuel CI jobs (verify-<repo>-<smth>)
------------------------------------------

* empty run with timer is configured
* job is enabled for stable branches, whenever possible
* job will work for all specified branches
* job uses its own label
* corresponding gate- job configured if applicable (see dualcheck- templates
  for examples)
