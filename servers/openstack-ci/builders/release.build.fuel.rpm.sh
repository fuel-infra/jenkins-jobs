#!/bin/bash -ex
source .debug-default || :

[ -z "$GERRIT_USER" ] && GERRIT_USER='openstack-ci-jenkins'
[ -z "$PRJSUFFIX" ] && PRJSUFFIX="-stable"
[ -z "$UPDATES_SUFFIX" ] && UPDATES_SUFFIX="-updates"
[ ! "$UPDATES" == "true" ] && unset UPDATES_SUFFIX
EXCLUDES='--exclude-vcs'
[ -z "$OBSURL" ] && OBSURL='https://osci-obs.vm.mirantis.net'
[ -z "$OBSAPI" ] && OBSAPI="-A ${OBSURL}:444"
[ -z "${GERRIT_SCHEME}" ] || URL="${GERRIT_SCHEME}://${GERRIT_USER}@${GERRIT_HOST}:${GERRIT_PORT}"
[ -z "$URL" ] && URL="ssh://${GERRIT_USER}@review.openstack.org:29418"
[ -z "$GERRIT_HOST" ] && GERRIT_HOST=`echo $URL | sed 's|[:/@]||g'`
GITDATA=${HOME}/gitdata/$GERRIT_HOST
WRKDIR=`pwd`

info () {
  echo
  echo -e "INFO: $*"
  echo
}

error () {
  echo
  echo -e "ERROR: $*"
  echo
  exit 1
}

job_lock() {
    local LOCKFILE=$1
    local TIMEOUT=600
    shift
    fd=15
    eval "exec $fd>$LOCKFILE"
    if [ "$1" = "set" ]; then
        flock --timeout $TIMEOUT -x $fd
    elif [ "$1" = "unset" ]; then
        flock -u $fd
        rm -f $LOCKFILE
    fi
}

fetch_upstream () {
  [ -n "$1" ] && local PACKAGENAME=$1
  shift
  [ -n "$1" ] && local SRCPROJECT=$1
  shift
  [ -n "$1" ] && local SPECPROJECT=$1

  local url=`echo $URL | sed "s|//.*@|//$GERRIT_USER@|"`
  # Do not clone projects every time. It makes gerrit sad. Cache it!
  for prj in $SRCPROJECT $SPECPROJECT; do
    # Update code base cache
    [ -d ${GITDATA} ] || mkdir -p ${GITDATA}
    if [ ! -d ${GITDATA}/$prj ]; then
      info "Cache for $prj doesn't exist. Cloning to ${HOME}/gitdata/$prj"
      mkdir -p ${GITDATA}/$prj
      # Lock cache directory
      job_lock ${GITDATA}/${prj}.lock set
      pushd ${GITDATA} &>/dev/null
      info "Cloning sources from $URL/$prj.git ..."
      git clone "$url/$prj.git" "$prj"
      popd &>/dev/null
    else
      # Lock cache directory
      job_lock ${GITDATA}/${prj}.lock set
      info "Updating cache for $prj"
      pushd ${GITDATA}/$prj &>/dev/null
      info "Fetching sources from $URL/$prj.git ..."
      git remote rm origin
      git remote add origin $url/$prj.git
      git fetch --all
      popd &>/dev/null
    fi
    if [ "$prj" == "$SRCPROJECT" ]; then
      _DIRSUFFIX="src"
      _BRANCH=$SOURCEBRANCH
      [ -n "$SOURCECHANGEID" ] && _CHANGEID=$SOURCECHANGEID
    fi
    if [ "$prj" == "$SPECPROJECT" ]; then
      _DIRSUFFIX="spec"
      _BRANCH=$SPECBRANCH
      [ -n "$SPECCHANGEID" ] && _CHANGEID=$SPECCHANGEID
    fi
    [ -e "${PACKAGENAME}-${_DIRSUFFIX}" ] && rm -rf "${PACKAGENAME}-${_DIRSUFFIX}"
    info "Getting $_DIRSUFFIX from $URL/$prj.git ..."
    cp -R ${GITDATA}/${prj} ${PACKAGENAME}-${_DIRSUFFIX}
    # Unlock cache directory
    job_lock ${GITDATA}/${prj}.lock unset
    pushd ${PACKAGENAME}-${_DIRSUFFIX} &>/dev/null
    switch_to_revision $_BRANCH
    # TODO: do not build package if _CHANGEID different from HEAD
    # Get code from HEAD if change is merged
    [ "$GERRIT_STATUS" == "MERGED" ] && unset _CHANGEID
    # If _CHANGEID specified switch to it
    [ -n "$_CHANGEID" ] && switch_to_changeset $prj $_CHANGEID
    popd &>/dev/null
    case $_DIRSUFFIX in
      "src") gitshasrc=$gitsha
        ;;
      "spec") gitshaspec=$gitsha
        ;;
      *) error "Unknown project type"
        ;;
    esac
    unset _DIRSUFFIX
    unset _BRANCH
    unset _CHANGEID
  done
}

switch_to_revision () {
  info "Switching to branch $*"
  if ! git checkout $*; then
    error "$* not accessible by default clone/fetch"
  else
    git reset --hard origin/$*
    gitsha=`git log -1 --pretty="%h"`
  fi
}

switch_to_changeset () {
  info "Switching to changeset $2"
  git fetch "$URL/$1.git" $2
  git checkout FETCH_HEAD
  gitsha=`git log -1 --pretty="%h"`
}

get_build_status() {
  local PRJNAME=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}${UPDATES_SUFFIX}
  local REPONAME=`osc $OBSAPI meta prj $PRJNAME | egrep -o "repository name=\"[a-z]+\"" | cut -d'"' -f2`
  local ARCH="x86_64"

  local finished='failed succeeded broken unresolvable disabled excluded'

  local status="schedulled"

  local timeout=12600
  local interval=30

  until [[ $finished =~ $status ]] || [ $timeout -eq 0 ]
  do
    sleep $interval
    timeout=$(( $timeout - $interval ))
    #status=`osc $OBSAPI api /build/$PROJECTNAME/_result | grep "\"$PACKAGENAME\"" | sed 's|^.*code="||;s|".*$||'`
    status=`osc $OBSAPI api /build/$PRJNAME/$REPONAME/$ARCH/$PACKAGENAME/_status | grep "<status" | sed 's|^.*code="||;s|".*$||'`
    local details=`osc $OBSAPI api /build/$PRJNAME/$REPONAME/$ARCH/$PACKAGENAME/_status | grep "<details" | sed 's|^.*<details>||;s|</details>||'`
  done

  [ "$details" == "" ] && details=none
  buildlogfile=${WRKDIR}/buildlog.${PACKAGENAME}.log
  buildresultfile=${WRKDIR}/buildlog.${PACKAGENAME}.xml
  [ "$status" != "unresolvable" ] && osc $OBSAPI api /build/$PRJNAME/$REPONAME/$ARCH/$PACKAGENAME/_log > $buildlogfile

  fill_buildresult $status $timeout $REPONAME $PACKAGENAME "$details" $buildlogfile > $buildresultfile
  rm -f $buildlogfile || :
  [ "$status" != "succeeded" ] && FAILED_PACKAGES="$FAILED_PACKAGES $PACKAGENAME" || :
  [ "$status" == "succeeded" ] && SUCCEED_PACKAGES="$SUCCEED_PACKAGES $PACKAGENAME" || :
}

fill_buildresult () {
    local buildstat=$1
    local istimeout=$2
    local reponame=$3
    local packagename=$4
    local builddetails=$5
    local buildlog=$6
    local failcnt=0
    [[ $buildstat == "succeeded" ]] || local failcnt=1
    if [ $timeout -eq 0 ]; then
        local failcnt=1
        local builddetails="Timeout reached. Last build status: $buildstat"
    fi
    [[ $reponame == "centos" ]] && local pkgtype=RPM || local pkgtype=DEB
    echo "<testsuite name=\"Package build\" tests=\"Package build\" errors=\"0\" failures=\"$failcnt\" skip=\"0\">"
    echo -n "<testcase classname=\"$pkgtype\" name=\"$packagename\" time=\"0\""
    if [[ $failcnt == 0 ]]; then
        echo "/>"
    else
        echo ">"
        echo "<failure type=\"Failure\" message=\"$buildstat\">"
        if [[ $buildstat == "failed" ]]; then
            echo "Last log:"
            cat $buildlog | sed 's|<|\&lt;|g; s|>|\&gt;|g'
        else
            echo "Details: $builddetails"
        fi
        echo "</failure>"
        echo "</testcase>"
    fi
    echo "</testsuite>"
}

create_updates_project() {
  local STBLPRJ=$1
  local UPDSPRJ=${STBLPRJ}${UPDATES_SUFFIX}
  # Check if updates project already exist
  local IS_UPD_EXIST=1
  osc $OBSAPI meta prj ubuntu-fuel-6.1-stable &>/dev/null || IS_UPD_EXIST=0

  # Create updates project
  if [ "$IS_UPD_EXIST" == "0" ]; then
    local conffile="${WRKDIR}/create_updates_project_config.xml"
    osc $OBSAPI meta prj $STBLPRJ > $conffile || error "Something went wrong"
    local reponame=`cat $conffile | egrep -o "repository name=\"[a-z]+\"" | cut -d'"' -f2`
    local stablepath='<path project="'$STBLPRJ'" repository="'$reponame'"/>'
    sed -i "s|$STBLPRJ|$UPDSPRJ|" $conffile
    sed -i "s|<title.*|<title>Updates repo for $STBLPRJ</title>|" $conffile
    [ -n "$stablepath" ] && sed -i "/repository name/a$stablepath" $conffile
    info "Creating new project $UPDSPRJ"
    osc $OBSAPI meta prj -F $conffile $UPDSPRJ || error "Something went wrong"
    rm -f $conffile
    local prjconffile="${WRKDIR}/copy_prjconf_from_stableprj_config.xml"
    osc $OBSAPI meta prjconf $STBLPRJ > $prjconffile || error "Something went wrong"
    osc $OBSAPI meta prjconf -F $prjconffile $UPDSPRJ || error "Something went wrong"
    rm -f $prjconffile
  fi
}


create_package() {
  local PRJNAME=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}${UPDATES_SUFFIX}
  [ "$UPDATES" == "true" ] && create_updates_project ${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}
  # Create package if it doesn't exst
  local conffile="$WRKDIR/create_package_config.xml"
  if ! osc $OBSAPI meta pkg $PRJNAME $PACKAGENAME &>/dev/null
  then
    cat >$conffile <<EOF
<package name="$PACKAGENAME" project="$PRJNAME">
  <title></title>
  <description></description>
</package>
EOF
    info "Creating new package $PACKAGENAME at project $PRJNAME"
    osc $OBSAPI meta pkg -F $conffile $PRJNAME $PACKAGENAME
  fi
  [ -e "$conffile" ] && rm -f $conffile || :
}

push_package_to_obs () {
  local PRJNAME=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}${UPDATES_SUFFIX}
  create_package
  local tmpdir="$WRKDIR/obs"
  [ -e "$tmpdir" ] && rm -rf $tmpdir
  mkdir -p $tmpdir
  pushd $tmpdir &>/dev/null
  # Get package tree from OBS
  osc $OBSAPI co $PRJNAME $PACKAGENAME
  cd $PRJNAME/$PACKAGENAME
  #Remove old files of package
  rm -f *
  #Add new files to package
  cp $WRKDIR/dst/*  $tmpdir/$PRJNAME/$PACKAGENAME/ || :
  osc $OBSAPI addremove
  local trmessage=`echo "$message" | head -20`
  info "Committing package $PACKAGENAME with message $trmessage"
  #Push updated package to OBS
  osc $OBSAPI commit -m "$trmessage" || exit 1
  popd &>/dev/null
  [ -e "$tmpdir" ] && rm -rf $tmpdir
}

get_revision() {
  [ -n "$1" ] && local REPO_TYPE=$1
  shift
  [ -n "$1" ] && local EXTRAREPO=$1
  shift
  [ -n "$1" ] && local binpackagenames=$1
  revision=0
  case $REPO_TYPE in
      rpm) # CentOS repo
           local yumdir=yumtest
           [ -d $yumdir ] && rm -rf $yumdir
           mkdir -p $yumdir/cache $yumdir/repos.d
           echo "#" > $yumdir/repos.d/test.repo
           cat > $yumdir/yum.conf<<EOL
[main]
cachedir=$yumdir/cache/
reposdir=$yumdir/repos.d/
keepcache=0
debuglevel=2
logfile=$yumdir/yum.log
exactarch=1
obsoletes=1
EOL
           local opts="-c $yumdir/yum.conf"
           if [ -n "$EXTRAREPO" ] ; then
              local CMD="sed -i"
              local OIFS="$IFS"
              IFS='|'
              for repo in $EXTRAREPO ; do
                IFS="$OIFS"
                local reponame=${repo%%,*}
                local repourl=${repo##*,}
                CMD="$CMD -e \"$ i[${reponame}]\nname=${reponame}\nbaseurl=${repourl}\ngpgcheck=0\nenabled=1\nskip_if_unavailable=1\n\""
                IFS='|'
              done
              IFS="$OIFS"
              CMD="$CMD $yumdir/repos.d/test.repo"
              [ -n "$CMD" ] && eval $CMD
           fi
           yum $opts clean all &>/dev/null
           revision=`LANGUAGE=C yum $opts info $binpackagenames | grep "^Release" | awk '{print $NF}' | sort -u | head -1 | egrep -o '[0-9]+$' || :`
           [ -d $yumdir ] && rm -rf $yumdir
           ;;
      deb) # Ubuntu repo
           aptdir=${WRKDIR}/apttest
           [ -d $aptdir ] && rm -rf $aptdir
           mkdir -p $aptdir/cache $aptdir/sources/parts $aptdir/lists
           touch $aptdir/status
           if [ -n "$EXTRAREPO" ] ; then
              local OIFS="$IFS"
              IFS='|'
              for repo in $EXTRAREPO ; do
                IFS="$OIFS"
                echo "deb $repo" >> $aptdir/sources/sources.list
                IFS='|'
              done
              IFS="$OIFS"
           fi
           opts="-o Dir::Etc::SourceParts=${aptdir}/sources/parts
                 -o Dir::Etc::SourceList=${aptdir}/sources/sources.list
                 -o Dir::State::Lists=${aptdir}/lists
                 -o Dir::State::status=${aptdir}/status
                 -o Dir::Cache=${aptdir}/cache"
           apt-get $opts update || :
           revision=`LANG=C apt-cache $opts policy $binpackagenames | grep "Candidate" | awk -F': ' '{print $2}' | sort -u | egrep -o '[0-9]+$' | head -1 || :`
           [ -n "$aptdir" ] && rm -rf $aptdir
           ;;
  esac
  [ -z "$revision" ] && revision=0
  # Increment revision
  revision=$(( $revision + 1 ))
}

request_is_merged () {
  local REF=$1
  local CHANGENUMBER=`echo $REF | cut -d '/' -f4`
  local result=1
  local status=`ssh ${GERRIT_USER}@${GERRIT_HOST} -p $GERRIT_PORT gerrit query --format=TEXT $CHANGENUMBER | egrep -o " +status:.*" | awk -F': ' '{print $2}'`
  [ "$status" == "MERGED" ] && local result=0
  return $result
}

prepare_rpm_source () {
    [ -n "$1" ] && local PACKAGENAME=$1 && shift
    [ -n "$1" ] && local SPECFILE=$1 && shift
    [ -n "$1" ] && local SRCPATH=$1 && shift
    [ -n "$1" ] && local SPECFILESSRC=$1 && shift
    [ -n "$1" ] && local SPECFILESDST=$1
    case $PACKAGENAME in
        "ruby21-rubygem-astute")
            pushd $SRCPATH &>/dev/null
            gem build astute.gemspec
            mv *.gem ${WRKDIR}/dst/
            popd &>/dev/null
            ;;
        "nailgun")
            job_lock ${SRCPATH}.lock set
            pushd $SRCPATH &>/dev/null
            npm install --cache ${HOME}/npm-cache
            #grunt build --static-dir=static_compressed
            ./node_modules/.bin/gulp build --static-dir=compressed_static
            rm -rf static
            mv compressed_static static
            python setup.py sdist -d ${WRKDIR}/dst/
            popd &>/dev/null
            job_lock ${SRCPATH}.lock unset
            ;;
        * )
            pushd $SRCPATH &>/dev/null
            # If it's python source - prepare python egg tarball
            [ -f "setup.py" ] && python setup.py sdist -d ${WRKDIR}/dst/ || :
            # If there is additional source files - prepare it
            if [ -n "$SPECFILESSRC" ] ; then
                FILESNUM=`echo $SPECFILESSRC | grep -o "|" | wc -l`
                FILESNUM=$(( $FILESNUM + 1 ))
                for (( i=1; i<=$FILESNUM; i++ )); do
                  srcfile=`echo $SPECFILESSRC | cut -d "|" -f $i`
                  dstfile=${WRKDIR}/dst/`echo $SPECFILESDST | cut -d "|" -f $i`
                  # if dst file is tarball - pack src folder content
                  if [ "${dstfile##*.}" == "gz" ] ; then
                      pushd $srcfile &>/dev/null
                      tar -czf $dstfile *
                      popd &>/dev/null
                  else
                      cp -R $srcfile $dstfile
                  fi
                done
            fi
            popd &>/dev/null
            ;;
    esac
}

build_rpm_fuel () {
    [ -n "$1" ] && local PACKAGENAME=$1 && shift
    [ -n "$1" ] && local SRCREPO=$1 && shift
    [ -n "$1" ] && local SPECREPO=$1 && shift
    [ -n "$1" ] && local SPECFILE=$1 && shift
    [ -n "$1" ] && local SRCPATH=$1 && shift
    [ -n "$1" ] && local SPECFILESSRC=$1 && shift
    [ -n "$1" ] && local SPECFILESDST=$1
    PACKAGES="$PACKAGES $PACKAGENAME"
    local RPMSPECFILES="${PACKAGENAME}-spec/$SPECFILE"
    local PRJNAME=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}
    local REPONAME=`osc $OBSAPI meta prj $PRJNAME | egrep -o "repository name=\"[a-z]+\"" | cut -d'"' -f2`
    #local ARCH=`osc $OBSAPI meta prj $PRJNAME | grep "<arch>" | awk -F'[<>]' '{print $3}'`
    fetch_upstream $PACKAGENAME $SRCREPO $SPECREPO

    [ -d $WRKDIR/dst ] && rm -rf $WRKDIR/dst
    mkdir -p $WRKDIR/dst
    local specfile=''
    for specfile in $RPMSPECFILES; do
      cp $specfile ${WRKDIR}/dst
    done
    specfile=`find ${WRKDIR}/dst/ -name *.spec`
    binpackagenames=`rpm -q --specfile $specfile --queryformat "%{NAME}-%{VERSION} "`

    EXTRAREPO="repo1,http://${OBSURL##*/}:82/${PRJNAME}/${REPONAME}"
    [ "$UPDATES" == 'true' ] && EXTRAREPO="${EXTRAREPO}|repo2,http://${OBSURL##*/}:82/${PRJNAME}${UPDATES_SUFFIX}/${REPONAME}"
    export EXTRAREPO

    get_revision rpm "$EXTRAREPO" "$binpackagenames"
    local release="fuel${PROJECT_VERSION}.mos${revision}"
    sed -i "s/Release:.*$/Release: ${release}/" $specfile
    prepare_rpm_source $PACKAGENAME $specfile ${PACKAGENAME}-src/$SRCPATH $SPECFILESSRC $SPECFILESDST
    #------------------
    # Push files to OBS
    #------------------
    push_package_to_obs
    rm -rf ${PACKAGENAME}-src || :
    rm -rf ${PACKAGENAME}-spec || :
    #--------------------------
    # Wait for building package
    #--------------------------
    echo
    echo "Starting build of $PACKAGENAME"
    echo "$OBSURL/package/live_build_log?arch=x86_64&package=$PACKAGENAME&project=${PRJNAME}${UPDATES_SUFFIX}&repository=centos"
    info "To abort build copy this URL to browser: $OBSURL/package/abort_build?arch=x86_64&project=${PRJNAME}${UPDATES_SUFFIX}&repo=centos&package=${PACKAGENAME}REMOVEME"
    get_build_status
    info "Repository URL: http:/${OBSURL#*/}:82/${PRJNAME}${UPDATES_SUFFIX}/centos"
}

main () {
  REQUEST_PROJECT=$GERRIT_PROJECT
  SOURCEBRANCH=$GERRIT_BRANCH
  SPECBRANCH=$GERRIT_BRANCH
  SOURCECHANGEID=$GERRIT_REFSPEC
  SPECCHANGEID=$GERRIT_REFSPEC

  [ -d 'request-src' ] && rm -rf request-src
  fetch_upstream request $REQUEST_PROJECT
  unset SOURCECHANGEID
  pushd request-src &>/dev/null
  message=`git log -n 1 | tail -n +5 | sed 's|^ *||'`
  CHANGED_FILES=`git diff --name-only HEAD~1`
  popd &>/dev/null
  [ -d 'request-src' ] && rm -rf request-src

  GERRIT_STATUS="NEW"
  if [ -n "$GERRIT_REFSPEC" ]; then
     request_is_merged $GERRIT_REFSPEC && GERRIT_STATUS="MERGED"
  fi
  FAILED_PACKAGES=''
  SUCCEEED_PACKAGES=''
  rm -f *.xml || :
  local packages=''
  for file in $CHANGED_FILES ; do
      case $REQUEST_PROJECT in
          "stackforge/fuel-main" )
              case $file in
                fuelmenu/* ) local package=fuelmenu.spec ;;
                * ) local package=`echo $file | cut -d'/' -f4` ;;
              esac
              ;;
          "stackforge/fuel-web" )
              case $file in
                  "bin/fencing-agent.rb|bin/fencing-agent.cron" ) local package=fencing-agent.spec ;;
                  "bin/agent"|"bin/nailgun-agent.cron" ) local package=nailgun-agent.spec ;;
                  network_checker/* ) local package=nailgun-net-check.spec ;;
                  tasklib/* ) local package=python-tasklib.spec ;;
                  fuel_agent/* ) local package=fuel-agent.spec ;;
                  nailgun/* ) local package=nailgun.spec ;;
                  shotgun/* ) local package=shotgun.spec ;;
              esac
              ;;
          "stackforge/fuel-astute")
              case $file in
                mcagents/* ) local package="nailgun-mcagents.spec ruby21-nailgun-mcagents.spec";;
                * ) local package=ruby21-rubygem-astute.spec ;;
              esac
              ;;
          "stackforge/fuel-ostf" ) local package=fuel-ostf.spec ;;
          "stackforge/python-fuelclient" ) local package=python-fuelclient.spec ;;
          #"stackforge/fuel-tasks-validator" ) local package=stackforge/fuel-tasks-validator.spec ;;
      esac
      [ "`echo "$packages" | egrep \" $package( |$)\" | wc -l`" == "0" ] && packages="$packages $package"
  done
  local package=''
  for package in $packages ; do
      case $package in
          'fuelmenu.spec')
              build_rpm_fuel fuelmenu stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/fuelmenu.spec fuelmenu
              ;;
          'python-fuelclient.spec')
              build_rpm_fuel python-fuelclient stackforge/python-fuelclient stackforge/fuel-main packages/rpm/specs/python-fuelclient.spec
              ;;
          'shotgun.spec')
              build_rpm_fuel shotgun stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/shotgun.spec shotgun
              ;;
          'nailgun.spec')
              build_rpm_fuel nailgun stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/nailgun.spec nailgun
              ;;
          'fuel-agent.spec')
              build_rpm_fuel fuel-agent stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/fuel-agent.spec fuel_agent \
                   "etc/fuel-agent/fuel-agent.conf.sample|cloud-init-templates" "fuel-agent.conf|fuel-agent-cloud-init-templates.tar.gz"
              ;;
          'python-tasklib.spec')
              build_rpm_fuel python-tasklib stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/python-tasklib.spec tasklib
              ;;
          'nailgun-net-check.spec')
              build_rpm_fuel nailgun-net-check stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/nailgun-net-check.spec network_checker
              ;;
          'nailgun-agent.spec')
              build_rpm_fuel nailgun-agent stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/nailgun-agent.spec bin \
                   "agent|nailgun-agent.cron" "agent|nailgun-agent.cron"
              ;;
          'fencing-agent.spec')
              build_rpm_fuel fencing-agent stackforge/fuel-web stackforge/fuel-main packages/rpm/specs/fencing-agent.spec bin \
                   "fencing-agent.cron|fencing-agent.rb" "fencing-agent.cron|fencing-agent.rb"
              ;;
          'nailgun-mcagents.spec')
              build_rpm_fuel nailgun-mcagents stackforge/fuel-astute stackforge/fuel-main packages/rpm/specs/nailgun-mcagents.spec "/" \
                  "mcagents" "mcagents.tar.gz"
              ;;
          'ruby21-rubygem-astute.spec')
              build_rpm_fuel ruby21-rubygem-astute stackforge/fuel-astute stackforge/fuel-main packages/rpm/specs/ruby21-rubygem-astute.spec
              ;;
          'fuel-ostf.spec')
              build_rpm_fuel fuel-ostf stackforge/fuel-ostf stackforge/fuel-main packages/rpm/specs/fuel-ostf.spec
              ;;
          'ruby21-nailgun-mcagents.spec')
              build_rpm_fuel ruby21-nailgun-mcagents stackforge/fuel-astute stackforge/fuel-main packages/rpm/specs/ruby21-nailgun-mcagents.spec "/" \
                  "mcagents" "nailgun-mcagents.tar.gz"
              ;;
          #'fuel-tasks-validator.spec' )
          #    build_rpm_fuel fuel-tasks-validator stackforge/fuel-tasks-validator stackforge/fuel-main packages/rpm/specs/fuel-tasks-validator.spec
          #    ;;

      esac
  done
  if [ -n "$FAILED_PACKAGES" ] ; then
      echo "Packages: $FAILED_PACKAGES"
      exit 1
  else
      echo "Packages: $SUCCEED_PACKAGES"
  fi
}

main $@

exit 0
