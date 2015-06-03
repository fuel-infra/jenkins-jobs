#!/bin/bash

# usage: ./compare_repos BASE_URL_OLD_REPO BASE_URL_NEW_REPO
# example: ./compare_repos http://osci-obs.vm.mirantis.net:82/ubuntu-fuel-6.0.1-stable http://osci-obs.vm.mirantis.net:82/ubuntu-fuel-6.1-stable
# repodiff require 'yum-utills' package installed.

set -ex

# variables
WGET=$(/usr/bin/which wget)
JOIN=$(/usr/bin/which join)
REPODIFF=$(/usr/bin/which repodiff)
DPKG=$(/usr/bin/which dpkg)

if [[ $TYPE == "DEB" ]]; then

  echo "Type is DEB"

  # download and simplyfy of the files list
  $WGET -q "$OLD/ubuntu/Packages" -O old_raw_list
  grep -A2 'Package:' old_raw_list | grep -v 'Source\|Architecture' | awk -F": "  'ORS=NR%3?" ":"\n" {print $2,$4}' | sort > old_list

  $WGET -q "$NEW/ubuntu/Packages" -O new_raw_list
  grep -A2 'Package:' new_raw_list | grep -v 'Source\|Architecture' | awk -F": "  'ORS=NR%3?" ":"\n" {print $2,$4}'  > new_list

  # join 2 lists in one
  $JOIN --nocheck-order old_list new_list > joined.list

  # making report

  INPUT_FILE="joined.list"

  # read line by line
  while read line

  do
    # definition of variables from each line
    PKG_NAME=$(echo "$line" | awk '{print $1}')
    OLD_VER=$(echo "$line" | awk '{print $2}')
    NEW_VER=$(echo "$line" | awk '{print $3}')

    # exit code for check 'does old version higther than new?'
    EX_CODE_GT=$("$DPKG" --compare-versions "$OLD_VER" gt "$NEW_VER"; echo $?)

    # exit code for check 'does old version lower than new?'
    EX_CODE_LT=$("$DPKG" --compare-versions "$OLD_VER" lt "$NEW_VER"; echo $?)

    # exit code for check 'does old version the same as new?'
    EX_CODE_EQ=$("$DPKG" --compare-versions "$OLD_VER" eq "$NEW_VER"; echo $?)

    # if exit code 0 - than old version is higher than new one - so that package is downgraded
    if [[ "$EX_CODE_GT" -eq 0 ]]; then
      echo "$PKG_NAME $OLD_VER > $NEW_VER downgraded"
    fi

    # if exit code 0 - than old version is lower than new one - so package is upgraded
    if [[ "$EX_CODE_LT" -eq 0 ]]; then
      echo "$PKG_NAME $OLD_VER $NEW_VER upgraded"
    fi

    # if exit code 0 - than old version is same as new one - so package is same
    if [[ "$EX_CODE_EQ" -eq 0 ]]; then
      echo "$PKG_NAME $OLD_VER > $NEW_VER same"
    fi

  done < $INPUT_FILE > raw_report.list

  # print report in a same format as 'repodiff' do
  echo -e "New packages:\n"

  awk '{
    if ($4 == "new_package") print $1;
  }' raw_report.list

  echo -e "Updated Packages:\n"

  awk '{
    if ($4 == "upgraded" || $4 == "downgraded") print $1": "$1"_"$2" > "$1"_"$3;
  }' raw_report.list

  echo -e "\n"
  echo -e "Summary:\n"
  echo -e "Added Packages: $(grep -c 'new_package' raw_report.list)"
  echo -e "Removed Packages: $(grep -c 'removed' raw_report.list)"
  echo -e "Modified Packages: $(grep -c 'upgraded\|downgraded' raw_report.list)"

fi

# using repodiff
if [[ $TYPE == "RPM" ]]; then

  echo "Type is RPM"
  $REPODIFF --simple --old="$OLD/centos" --new="$NEW/centos"

fi
