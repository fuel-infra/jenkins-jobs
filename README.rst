Repo Structure
==============

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

``servers/fuel-ci/``

https://ci.fuel-infra.org/

``servers/infra-ci/``

https://infra-ci.fuel-infra.org/

``servers/jenkins-product-ci/``

http://jenkins-product.srt.mirantis.net:8080/

``servers/product-ci/``

https://product-ci.infra.mirantis.net/

``servers/old-stable-ci/``

https://old-stable-ci.infra.mirantis.net/

``servers/openstack-ci/``

http://osci-jenkins.srt.mirantis.net:8080/

``servers/patching-ci/``

https://patching-ci.infra.mirantis.net/

``servers/pkgs-ci/``

https://packaging-ci.infra.mirantis.net/

``servers/plugins-ci/``

https://plugin-ci.fuel-infra.org/

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

YAML JJB configs
----------------

* Use sample yaml files from the samples directory for reference:

  - Add description to the file and to all configuration entities i.e.
    job definition, job group, job template, project.

  - Keep the same order of the job parameters and configuration sections
    (i.e. wrappers, builders, etc.)

  - Separate JJB parameters (name, description, etc.) from project specific ones
    (version-id, mos, etc.) using blank line.

  - Place parameters that are parts of the name of job template or job group
    at the beginning of the project specific parameters list.

  - Insert a blank line after job parameters and between configuration sections
    (wrappers, builders, etc.). Also in project and job group leave blank line
    between their native parameters (e.g. name) and parameters that are provided
    to job templates or job groups.

* Style guide for work with list and dict (maps) data structures. These rules
  are not for the native JJB job parameters.

  - sort items in a way to be able to group them, if possible

  - do not separate items by an empty line within the same logical group

  - separate logical groups by an empty line

  - sort logical groups by importance

  - move all single disconnected and nongrouped items to the end of the data
    structure and group them, if possible.

  - if nested data structure consists of 2 or more groups then its data should
    be separated by empty lines at the begin and at the end of the structure.
    Parent item that holds mentioned data structure should be separated by
    an empty line within its data structure as well.

  - if in a result after applying these rules items become separated by 2 or
    more empty lines, the separator must be cut to only 1 emply line.

* Store job definitions, job templates, job groups and projects in separate
  files.

* Try to keep one job definition or job template per file.

* Use job templates instead of simple job definition if several nearly identical
  jobs are going to be created or a job needs custom (not JJB native) configuration
  parameter from job defaults.

* If job group is used pay double attention to the correctness of the template
  names to realize. If the template with requested name does not exist JJB will skip
  this fact without any errors. Thus necessary job configs will not be generated.

* If there are several jobs created for different source branches from the same
  template and some changes incompatible with older branches are coming to the
  template, new template for those source branches has to be branched from the old one
  and put to an appropriate directory, e.g.::

    servers/fuel-ci/job-template.yaml to servers/fuel-ci/9.0/job-template.yaml

    common/job-template.yaml to common/9.0/job-template.yaml

  In this case branch name has to be hard-coded in the job-template name.

  This rule works for job groups and projects as well.

  Once template is branched make sure that new project uses correct template name,
  i.e. with hard-coded branch name.

Shell-scripts
-------------

* Use::

    #!/bin/bash

    set -ex

  whenever possible. In case this rule can not be used, leave a
  comment in the script.

* Readability matters. Add comments for all specific actions.

* We mostly follow Google's guidelines: https://google.github.io/styleguide/shell.xml

* Use ``source`` command instead of ``.``

* Use ``$(command)`` instead of backticks

* Follow usual BASH coding-style, for example use ``${SOME_VAR}``
  instead of ``$SOME_VAR`` whenever possible. See include-raw section
  for exceptions.

* Try to limit line length to 100 symbols whenever possible.

* Shellcheck is a law. If your changes don't pass shellcheck, you must fix problems.

* There are some old scripts appeared before shellcheck, if you encoutered shellcheck errors
  while editing these files and you are able to fix this errors, please fix them in the same patch.
  If there are few errors you could fix them in the same patch.
  If there are lots of them, feel free to create another patch we'll accept it with gladness.
  When you are not able to fix this errors, please contact maintainers for help.

* ``# shellcheck disable=XXXX`` is a very exceptional case.

* Try to avoid ``cmd1 && cmd2 || cmd3``,
  see https://github.com/koalaman/shellcheck/wiki/SC2015 for details

* Consider to look at https://github.com/koalaman/shellcheck/wiki/
  there are lot's of good howto's

include-raw vs include-raw-escape
---------------------------------

NOTE: As include-raw-escape does unnecessary escaping when used in job
configuration, it should be used only in job templates.

When script/text file is included into *job* config:

   - use ``!include-raw``

When script/text file is included into *job-template* config:

   - use ``!include-raw-escape``

When script file is included into *job-template* config and you
need to pass certain parameters from the template to it, consider
injecting variables via env-inject plugin.

When text file is included into *job-template* config and you
need to pass certain parameters from the template to it:

   - use ``!include-raw``
   - curly brackets only for template parameters

Simple Fuel CI jobs (verify-<repo>-<smth>)
------------------------------------------

* empty run with timer is configured
* job is enabled for stable branches, whenever possible
* job will work for all specified branches
* job uses its own label
* corresponding gate- job configured if applicable (see dualcheck- templates
  for examples)
