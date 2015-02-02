#!/bin/bash -ex
function job_lock() {
    [ -z "$1" ] && exit_with_error "Lock file is not specified"
    local LOCKFILE=$1
    shift
    fd=15
    eval "exec $fd>$LOCKFILE"
    case $1 in
        "set")
            flock -x -n $fd \
                || exit_with_error "Process already running. Lockfile: $LOCKFILE"
            ;;
        "unset")
            flock -u $fd
            rm -f $LOCKFILE
            ;;
        "wait")
            TIMEOUT=${2:-3600}
            echo "Waiting of concurrent process (lockfile: $LOCKFILE, timeout = $TIMEOUT seconds) ..."
            flock -x -w $TIMEOUT $fd \
                && echo DONE \
                || exit_with_error "Timeout error (lockfile: $LOCKFILE)"
            ;;
    esac
}

function update-reprepro() {
    project=$1
    dist=$2
    export REPREPRO_BASE_DIR=/srv/obs/repos/$project/reprepro
    
    CURRENT_VERSION=5.1
    
    VERSION=`echo $project | cut -d"-" -f3`
    
    verlte() {
        [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
    }
    
    verlt() {
        [ "$1" = "$2" ] && return 1 || verlte $1 $2
    }
    
    verlt $VERSION $CURRENT_VERSION && BACKPORT=1
    
    if ! [ -f $REPREPRO_BASE_DIR/conf/distributions ]; then
      local LIMIT=60
      local TRIES=0
      while true; do
        if [[ $TRIES -gt 0 && $TRIES -ge $LIMIT ]]; then
          echo "Timeout reached"
          exit 1
        fi
        [ -d "/srv/obs/repos/$project" ] && break || :
        ((++TRIES))
        sleep 10
      done
      sudo mkdir -p $REPREPRO_BASE_DIR/conf
      sudo chown -R jenkins.obsrun $REPREPRO_BASE_DIR
      cat > $REPREPRO_BASE_DIR/conf/distributions <<EOF
Origin: Mirantis
Label: Mirantis FUEL
Suite: unstable
Codename: $dist
Version: $VERSION
Architectures: amd64 source i386
Components: main
Description: FUEL $VERSION packages
#SignWith: product
UDebComponents: main
Contents: . .gz .bz2
EOF
    fi
    sudo chown -R jenkins.obsrun $REPREPRO_BASE_DIR
    reprepro includedeb $dist `find /srv/obs/repos/$project/ubuntu/ -name \*.deb | tr '\n' ' '`
    [ "`find /srv/obs/build/$project/ubuntu/x86_64/:repo -name \*.udeb | wc -l`" != "0" ] && \
          reprepro includeudeb $dist `find /srv/obs/build/$project/ubuntu/x86_64/:repo -name \*.udeb | tr '\n' ' '`
    #if [[ "${project##*-}" != "testing" ]] && [[ "${project##*-}" != "updates" ]]; then
    #  for i in `find /home/jenkins/manual-packages -name \*deb` ; do reprepro -S database -P optional includedeb $dist $i; done
    #  for i in `find /home/jenkins/manual-kernels -name \*.deb` ; do reprepro -S database -P optional includedeb $dist $i; done
    #  for i in `find /home/jenkins/manual-kernels -name \*.udeb` ; do reprepro -S database -P optional includeudeb $dist $i; done
    #  [[ $BACKPORT ]] && for i in `find /home/jenkins/manual-backports/$VERSION -name \*.deb` ; do reprepro -S database -P optional includedeb $dist $i; done
    #  [[ $BACKPORT ]] && for i in `find /home/jenkins/manual-backports/$VERSION -name \*.udeb` ; do reprepro -S database -P optional includeudeb $dist $i; done
    #fi
    reprepro -Vb $REPREPRO_BASE_DIR export
    sudo chown -R obsrun.obsrun $REPREPRO_BASE_DIR
}

WORKSPACE=`pwd`
REPONAME=$1
[ -n "$2" ] && DISTRO=$2 || DISTRO=trusty

if ! [ -f ${WORKSPACE}/${REPONAME}.state ]
then
    echo "Previous state of $REPONAME repo is unknown."
    echo "Save current state as previous and run reprepro"
    job_lock ${WORKSPACE}/${REPONAME}.lock wait
    update-reprepro $REPONAME $DISTRO 2>&1 | tee reprepro.log
    job_lock ${WORKSPACE}/${REPONAME}.lock unset
    echo "PREVIOUSSTATE=`osc api /build/$REPONAME/ubuntu/x86_64/_repository | \
          sha256sum | cut -d " " -f1`" > ${WORKSPACE}/${REPONAME}.state
else
    source ${WORKSPACE}/${REPONAME}.state
    CURRENTSTATE=`osc api \
                  /build/$REPONAME/ubuntu/x86_64/_repository | sha256sum | cut -d " " -f1`
    if [[ $PREVIOUSSTATE != $CURRENTSTATE ]]
    then
        echo "State of $REPONAME repo changed. Run reprepro"
        update-reprepro $REPONAME $DISTRO 2>&1 | tee reprepro.log
        echo "PREVIOUSSTATE=$CURRENTSTATE" > ${WORKSPACE}/${REPONAME}.state
    else
      echo "State of $REPONAME repo was not changed."
    fi
fi

#for skipped in `cat reprepro.log | grep ^Skipp | awk '{print $4"|"$5"|"$12}'`; do
#    newver=`echo $skipped | awk -F"[']" '{print $4}'`
#    existver=`echo $skipped | awk -F"[']" '{print $6}'`
#    [[ $newver == $existver ]] || echo $skipped
#done
