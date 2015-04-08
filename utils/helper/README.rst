Helper tool to manage Jenkins slaves
------------------------------------

Can be used to collect data and run management tasks on slaves based
on labels. Don't use authentication.

Based on fabric, thus you need the package to be installed::

  yum install fabric

or::

  apt-get install fabric

Examples
--------

- list of slaves by label::

    fab product_ci:swarm

- run simple command::

    fab fuel_ci:master_centos -- uname -a

- list all environments for Product CI slaves for label `bvt`::

    fab product_ci:bvt dos_py:list dos_py_29:list publish:rst

- print devops versions for Fuel CI slaves for label `master_centos`::

    fab fuel_ci:master_centos dos_py_29:version publish:csv

- run arbitrary command
