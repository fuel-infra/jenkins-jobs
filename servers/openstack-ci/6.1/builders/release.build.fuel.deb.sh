#!/bin/bash -ex
[ -f .debug-default ] && source .debug-default

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
  [ "$GERRIT_STATUS" == "NEW" ] && PRJNAME="${PRJNAME}-${GERRIT_CHANGE_NUMBER}"
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
    [ "$reponame" == "centos" ] && local pkgtype=RPM || local pkgtype=DEB
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

create_project() {
  local PARENTPRJ=$1
  local NEWPRJ=$2
  local COMMENT=$3 || :
  [ "$COMMENT" == "" ] && local COMMENT="Child project for ${PARENTPRJ}"
  # Check if new project already exist
  local IS_PRJ_EXIST=1
  osc $OBSAPI meta prj $NEWPRJ &>/dev/null || IS_UPD_EXIST=0

  # Create project
  if [ "$IS_UPD_EXIST" == "0" ]; then
    local conffile="${WRKDIR}/create_project_config.xml"
    osc $OBSAPI meta prj $PARENTPRJ > $conffile || error "Something went wrong"
    local reponame=`cat $conffile | egrep -o "repository name=\"[a-z]+\"" | cut -d'"' -f2`
    local parentpath='<path project="'$PARENTPRJ'" repository="'$reponame'"/>'
    sed -i "s|$PARENTPRJ|$NEWPRJ|" $conffile
    sed -i "s|<title.*|<title>${COMMENT}</title>|" $conffile
    [ -n "$parentpath" ] && sed -i "/repository name/a$parentpath" $conffile
    info "Creating new project $NEWPRJ"
    osc $OBSAPI meta prj -F $conffile $NEWPRJ || error "Something went wrong"
    rm -f $conffile
    local prjconffile="${WRKDIR}/copy_prjconf_from_parentprj_config.xml"
    osc $OBSAPI meta prjconf $PARENTPRJ > $prjconffile || error "Something went wrong"
    osc $OBSAPI meta prjconf -F $prjconffile $NEWPRJ || error "Something went wrong"
    rm -f $prjconffile
  fi
}

create_package() {
  local PRJNAME=$1
  local PACKAGENAME=$2
  # Create package if it doesn't exist
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

generate_dsc () {
  #Some magic with sed and awk
  local DSCFILE=$1
  local DEBIAN_FOLDER=$2
  local TARBALL_FOLDER=$3

  echo "Format: 3.0 (quilt)" > "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | grep -E '^Source' >> "$DSCFILE"
  echo -n "Binary: " >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | grep "^Package:" | awk '{print $2}' | sed -e :a -e "/$/N; s/\n/, /; ta" >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | grep "^Architecture" | tail -1 >> "$DSCFILE"
  echo -n "Version: " >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/changelog | head -1 | awk -F '[(,)]' '{ print $2 }' >> "$DSCFILE"
  #echo $fullver >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | grep -E '^Maintainer' >> "$DSCFILE" || :
  cat ${DEBIAN_FOLDER}/control | sed 's|#.*$||' | sed -n -e '/^Uploaders/,/^\w/p' | sed '$d' | sed -e :a -e "/$/N; s/\n//; ta" >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | sed 's|#.*$||' | sed -n -e '/^Build-Depends:/,/^\w/p' | sed '$d' | sed -e :a -e "/$/N; s/\n//; ta" >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | sed 's|#.*$||' | sed -n -e '/^Build-Depends-Indep/,/^\w/p' | sed '$d' | sed -e :a -e "/$/N; s/\n//; ta" >> "$DSCFILE"
  cat ${DEBIAN_FOLDER}/control | grep -E '^Standards-Version' >> "$DSCFILE" || :
  cat ${DEBIAN_FOLDER}/control | grep -E '^Homepage' | head -1 >> "$DSCFILE" || :
  cat ${DEBIAN_FOLDER}/control | grep -E '^Vcs-Browser' >> "$DSCFILE" || :
  cat ${DEBIAN_FOLDER}/control | grep -E '^Vcs-Bzr' >> "$DSCFILE" || :
  echo "Package-List:" >> "$DSCFILE"
  local globSection=`cat ${DEBIAN_FOLDER}/control | sed 's|#.*$||' | grep -E '^Section' | head -1 | awk '{print $2}'`
  local globPriority=`cat ${DEBIAN_FOLDER}/control | sed 's|#.*$||' | grep -E '^Priority' | head -1 | awk '{print $2}'`
  cat ${DEBIAN_FOLDER}/control | sed 's|#.*$||' | grep -E "^(Package|Section|Priority|$)" | \
    awk 'BEGIN { FS="\n"; RS=""; ORS = " "} \
    { print $1; \
      if (!index ($0, "Section")) \
         print "Section: '$globSection'"; \
      else \
         print $2; \
      if (!index ($0, "Priority")) \
         print "Priority: '$globPriority'"; \
      else \
         print $3; \
      print "\n"}' | \
    sed 's|Package: ||;s|Section: |deb |;s|Priority: ||' | sed -e '1d;$d' >> "$DSCFILE"
  echo "Checksums-Sha1:" >> "$DSCFILE"
  local TARBALLS=`find ${TARBALL_FOLDER}/ -maxdepth 1 -name "*.tar.gz"`
  for i in $TARBALLS; do
    local filename=`ls -la $i | awk '{print $9}' | sed -e "s|^${TARBALL_FOLDER}/||"`
    local filesize=`ls -la $i | awk '{print $5}'`
    local filechecksum=`sha1sum $i | awk '{print $1}'`
    echo " $filechecksum $filesize $filename" >> "$DSCFILE"
  done
  echo "Checksums-Sha256:" >> "$DSCFILE"
  for i in $TARBALLS; do
    local filename=`ls -la $i | awk '{print $9}' | sed -e "s|^${TARBALL_FOLDER}/||"`
    local filesize=`ls -la $i | awk '{print $5}'`
    local filechecksum=`sha256sum $i | awk '{print $1}'`
    echo " $filechecksum $filesize $filename" >> "$DSCFILE"
  done
  echo "Files:" >> "$DSCFILE"
  for i in $TARBALLS; do
    local filename=`ls -la $i | awk '{print $9}' | sed -e "s|^${TARBALL_FOLDER}/||"`
    local filesize=`ls -la $i | awk '{print $5}'`
    local filechecksum=`md5sum $i | awk '{print $1}'`
    echo " $filechecksum $filesize $filename" >> "$DSCFILE"
  done
  cat ${DEBIAN_FOLDER}/control | grep 'Original-Maintainer' | sed 's|XSBC-||' >> "$DSCFILE"
}

push_package_to_obs () {
  local MAINPRJ=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}
  [ "$UPDATES" == "true" ] && create_project ${MAINPRJ} ${MAINPRJ}${UPDATES_SUFFIX} "Updates repo for ${MAINPRJ}"
  local PRJNAME=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}${UPDATES_SUFFIX}
  if [ "$GERRIT_STATUS" == "NEW" ] ; then
      local CRSUFFIX="-$GERRIT_CHANGE_NUMBER"
      local PRJNAME=${PRJNAME}${CRSUFFIX}
      create_project ${MAINPRJ}${UPDATES_SUFFIX} ${PRJNAME} "Package $PACKAGENAME from changeset"
  fi
  create_package $PRJNAME $PACKAGENAME
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

build_deb_fuel () {
    # build_deb_fuel packagename srcrepo specpath
    [ -n "$1" ] && local PACKAGENAME=$1 && shift
    [ -n "$1" ] && local SRCREPO=$1 && shift
    [ -n "$1" ] && local SPECPATH=$1 && shift
    [ "$GERRIT_STATUS" == "NEW" ] && local CRSUFFIX="-${GERRIT_CHANGE_NUMBER}"
    PACKAGES="$PACKAGES $PACKAGENAME"
    local DEBSPECFILES="${PACKAGENAME}-src/$SPECPATH/debian"
    local PRJNAME=${PRJPREFIX}${PROJECTNAME}${PRJSUFFIX}
    local REPONAME=`osc $OBSAPI meta prj $PRJNAME | egrep -o "repository name=\"[a-z]+\"" | cut -d'"' -f2`
    fetch_upstream $PACKAGENAME $SRCREPO

    [ -d $WRKDIR/dst ] && rm -rf $WRKDIR/dst
    mkdir -p $WRKDIR/dst/src

    local specfile=''
    for specfile in $DEBSPECFILES; do
      cp -R $specfile ${WRKDIR}/dst
    done

    local debpackagename=`cat ${WRKDIR}/dst/debian/changelog | head -1 | cut -d' ' -f1`
    local version=`cat ${WRKDIR}/dst/debian/changelog | head -1 | cut -d' ' -f2 | sed 's|(||;s|\-.*||'`
    local binpackagenames="`cat ${WRKDIR}/dst/debian/control | grep ^Package | cut -d' ' -f 2 | tr '\n' ' '`"
    local epochnumber=`cat ${WRKDIR}/dst/debian/changelog | head -1 | grep -o "(.:" | sed 's|(||'`

    rsync -aPt --exclude '.git*' ${PACKAGENAME}-src/ $WRKDIR/dst/src/
    pushd ${PACKAGENAME}-src/ &>/dev/null
    message=`git log -n 1 | tail -n +5 | sed 's|^ *||'`
    #local release="r`git rev-list --no-merges HEAD |wc -l`"
    #local release="${release}~g`git rev-parse --short HEAD`"
    popd &>/dev/null

    EXTRAREPO="http://${OBSURL##*/}:82/${PRJNAME}/${REPONAME} /"
    [ "$UPDATES" == 'true' ] && EXTRAREPO="${EXTRAREPO}|http://${OBSURL##*/}:82/${PRJNAME}${UPDATES_SUFFIX}/${REPONAME} /"
    export EXTRAREPO

    get_revision deb "$EXTRAREPO" "$binpackagenames"
    local release="fuel${PROJECT_VERSION}+${revision}"
    local fullver=${epochnumber}${version}-${release}

    sed -i "s| (.*) | (${fullver}) |" ${WRKDIR}/dst/debian/changelog
    TAR_SPECNAME="${debpackagename}_${fullver#*:}.debian.tar.gz"
    pushd ${WRKDIR}/dst/ &>/dev/null
    tar --owner=root --group=root -czf ${WRKDIR}/dst/${TAR_SPECNAME} --exclude-vcs debian
    cd src
    TAR_ORIGNAME="${debpackagename}_${version#*:}.orig.tar.gz"
    tar --owner=root --group=root -czf ${WRKDIR}/dst/${TAR_ORIGNAME} --exclude-vcs *

    popd &>/dev/null

    generate_dsc ${WRKDIR}/dst/${debpackagename}_${fullver#*:}.dsc ${WRKDIR}/dst/debian ${WRKDIR}/dst
    #------------------
    # Push files to OBS
    #------------------
    push_package_to_obs
    rm -rf ${PACKAGENAME}-src
    rm -rf ${PACKAGENAME}-spec
    #--------------------------
    # Wait for building package
    #--------------------------
    echo
    echo "Starting build of $PACKAGENAME"
    echo "$OBSURL/package/live_build_log?arch=x86_64&package=$PACKAGENAME&project=${PRJNAME}${UPDATES_SUFFIX}${CRSUFFIX}&repository=${REPONAME}"
    info "To abort build copy this URL to browser: $OBSURL/package/abort_build?arch=x86_64&project=${PRJNAME}${UPDATES_SUFFIX}${CRSUFFIX}&repo=${REPONAME}&package=${PACKAGENAME}REMOVEME"
    get_build_status
    info "Repository URL: http:/${OBSURL#*/}:82/${PRJNAME}${UPDATES_SUFFIX}${CRSUFFIX}/${REPONAME}"
}

main () {
  [ -f .debug-default ] && source .debug-default
  SOURCEBRANCH=$GERRIT_BRANCH
  SPECBRANCH=$GERRIT_BRANCH
  SOURCECHANGEID=$GERRIT_REFSPEC
  SPECCHANGEID=$GERRIT_REFSPEC
  GERRIT_STATUS="NEW"
  if [ -n "$GERRIT_REFSPEC" ]; then
     request_is_merged $GERRIT_REFSPEC && GERRIT_STATUS="MERGED"
  fi
  FAILED_PACKAGES=''
  SUCCEEED_PACKAGES=''
  rm -f *.xml
  case $GERRIT_PROJECT in
      "stackforge/fuel-astute" )
          build_deb_fuel fuel-astute stackforge/fuel-astute
          ;;
      "stackforge/fuel-web" )
          build_deb_fuel nailgun stackforge/fuel-web
          ;;
      "stackforge/fuel-library" )
          build_deb_fuel fuel-library stackforge/fuel-library
          ;;
  esac

  if [ -n "$FAILED_PACKAGES" ] ; then
      echo "Packages: $FAILED_PACKAGES"
      exit 1
  else
      echo "Packages: $SUCCEED_PACKAGES"
  fi
}

main $@

exit 0
