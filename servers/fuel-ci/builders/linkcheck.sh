#!/bin/bash

set -ex

WS=${WORKSPACE}

virtualenv _requirenv
source _requirenv/bin/activate
pip install -r ${REQUIREMENTS}

cd ${MAKEDIR}

(make linkcheck || true) | tee ${WS}/make_output_current.txt

if [ -f ${WS}/make_output.txt ]
then
  sort ${WS}/make_output.txt | sed 's/\s\s*/ /g' | \
    cut -d ' ' -f 3- > ${WS}/make_output_sorted.txt
  sort ${WS}/make_output_current.txt | sed 's/\s\s*/ /g' | \
    cut -d ' ' -f 3- > ${WS}/make_output_current_sorted.txt
  (diff ${WS}/make_output_sorted.txt ${WS}/make_output_current_sorted.txt || true) | \
    egrep 'http*.:' | tee ${WS}/difference.txt
  rm ${WS}/make_output_sorted.txt ${WS}/make_output_current_sorted.txt
fi

mv ${WS}/make_output_current.txt ${WS}/make_output.txt

egrep 'http.*:' ${WS}/make_output.txt |\
  sed 's/\s\s*/ /g' | egrep -w -v "${REGEX}" > ${WS}/missing.txt
