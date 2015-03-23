. ../venv-nailgun-tests-2.9/bin/activate

export ISO_PATH=$(ls -1t /mnt/downloads/fuel-6.1-*.iso | head -1)
export POOL_DEFAULT=10.108.0.0/16:24

export ADMIN_NODE_MEMORY=2048
export ADMIN_NODE_CPU=2
export SLAVE_NODE_MEMORY=2572
export SLAVE_NODE_CPU=1
export NODE_VOLUME_SIZE=100
export USE_ALL_DISKS='true'
export NODES_COUNT=9

export ADMIN_FORWARD='nat'
export PUBLIC_FORWARD='nat'

export BONDING='false'
export SERVTEST_USERNAME='admin'
export SERVTEST_PASSWORD='admin'
export SERVTEST_TENANT='admin'

export OPENSTACK_RELEASE=Ubuntu

export PYTHONPATH=$PWD

export VENV_PATH='/home/jenkins/venv-nailgun-tests-2.9'
export LOCAL_MIRROR_UBUNTU='/home/jenkins/'
export DJANGO_SETTINGS_MODULE=devops.settings

./utils/jenkins/system_tests.sh -t test -w $PWD -j plugins -i $ISO_PATH  -o --group=prepare_slaves_9 -K
