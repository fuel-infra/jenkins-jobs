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

WRK_DIR=`pwd`
[ -n "$1" ] && PROJECTNAME=$1 && shift
[ -n "$1" ] && REPONAME=$1 && shift
[ -n "$*" ] && PACKAGES=$*
[ -z "$PROJECTNAME" ] && exit 1
[ -z "$REPONAME" ] && exit 1
[ -z "$PACKAGES" ] && exit 1
REPO=/srv/obs/repos/${PROJECTNAME}/${REPONAME}
SECREPO=/srv/obs/repos/${PROJECTNAME%%-updates*}-security/${REPONAME}

job_lock ${WRK_DIR}/${PROJECTNAME}.lock wait
case ${PACKAGES##*.} in
  rpm )
        sudo mkdir -p ${SECREPO}/{Packages,Sources,repodata}
        sudo chown -R jenkins.obsrun ${SECREPO%/*}

        for package in $PACKAGES ; do
            PACKAGEFOLDER=Packages
            [ "${package:(-7)}" == "src.rpm" ] && PACKAGEFOLDER=Sources
            # Wait packages at repo
            LIMIT=60
            TRIES=0
            while true ; do
                if [[ $TRIES -gt 0 && $TRIES -ge $LIMIT ]]; then
                    echo "Timeout reached"
                    exit 1
                fi
                [ "`find ${REPO} -name $package | wc -l`" != "0" ] && break || :
                ((++TRIES))
                sleep 10
            done

            for file in `find ${REPO} -name $package` ; do
              cp $file ${SECREPO}/${PACKAGEFOLDER}/
            done
        done

        createrepo $SECREPO
        ;;
    * )
        sudo mkdir -p ${SECREPO}/conf
        sudo chown -R jenkins.obsrun ${SECREPO%/*}

        cp /srv/obs/repos/${PROJECTNAME}/reprepro/conf/* ${SECREPO}/conf
        dist=`cat ${SECREPO}/conf/distributions | grep "^Codename" | awk '{print $2}'`
        BINDEBLIST=""
        BINUDEBLIST=""
        BINSRCLIST=""
        for package in $PACKAGES ; do
          packagefile=`find /srv/obs/repos/${PROJECTNAME}/${REPONAME}/ -name $package`
          case ${packagefile##*.} in
             deb ) BINDEBLIST="$BINDEBLIST $packagefile" ;;
            udeb ) BINUDEBLIST="$BINDEBLIST $packagefile" ;;
             dsc ) BINSRCLIST="$BINSRCLIST $packagefile" ;;
          esac
        done
        [ -n "$BINDEBLIST" ] && reprepro --basedir ${SECREPO} includedeb $dist $BINDEBLIST
        [ -n "$BINUDEBLIST" ] && reprepro --basedir ${SECREPO} includeudeb $dist $BINUDEBLIST
        if [ -n "$BINSRCLIST" ]; then
          SRCPACKNAME=${BINSRCLIST%%_*}
          SRCPACKNAME=${SRCPACKNAME##*/}
          reprepro --basedir ${SECREPO} -A source remove $dist $SRCPACKNAME || :
          reprepro --basedir ${SECREPO} includedsc $dist ${BINSRCLIST[@]}
        fi
        ;;
esac

sudo chown -R obsrun.obsrun ${SECREPO%/*}

job_lock ${WRK_DIR}/${PROJECTNAME}.lock unset
