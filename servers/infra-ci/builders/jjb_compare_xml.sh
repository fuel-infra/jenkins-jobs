#!/bin/bash

set -ex

GITHEAD=$(git rev-parse HEAD)
JOBS_OUT_DIR=${WORKSPACE}/output/jobs
JOBS_LOGFILE=${JOBS_OUT_DIR}/jobs-diff.log
VIEWS_OUT_DIR=${WORKSPACE}/output/views
VIEWS_LOGFILE=${VIEWS_OUT_DIR}/views-diff.log
RESULT=''
BLOCKLIST=blocklist

# First generate output from BASE_COMMIT vars value
git checkout "${BASE_COMMIT}"

for ENV in ${WORKSPACE}/servers/*; do
  tox -e compare-xml-old -- "${ENV##*/}"
done

for VIEW_ENV in ${WORKSPACE}/views/*; do
  tox -e compare-view-xml-old -- "${VIEW_ENV##*/}"
done

# Then use that as a reference to compare against HEAD
git checkout "${GITHEAD}"

for ENV in ${WORKSPACE}/servers/*; do
  tox -e compare-xml-new -- "${ENV##*/}"
done

for VIEW_ENV in ${WORKSPACE}/views/*; do
  tox -e compare-view-xml-new -- "${VIEW_ENV##*/}"
done


compare_xml() {

# Replace arguments with built-in variables ($1 - path to jobs or views output directory, $2 - path to jobs or views log file)
OUT_DIR=$1
LOGFILE=$2
# Specifying for http links type of comaprison (jobs or views)
TYPE=$3

BLOCK=0
CHANGE=0
ADD=0
REMOVE=0

BLOCKED="[blocked]<br>"
CHANGED="[changed]<br>"
ADDED="[added]<br>"
REMOVED="[removed]<br>"

DIFF=$(diff -q -r -u "${OUT_DIR}/old" "${OUT_DIR}/new" &>"${LOGFILE}"; echo "${?}")
# Any changed job discovered? If exit code was 1, then there is a difference
if [[ ${DIFF} -eq 1 ]]; then
  # Loop through all changed jobs and compare them with a blocklist
  for JOB in $(awk '/Files/ {print $2}' "${LOGFILE}"); do
    # Extract job's name
    JOB_NAME=$(basename "${JOB}")
    # Extract job's ENV name (server/${ENV} to make sure,
    # that we are comparing ENV/JOB_NAME with right ENV/BLOCKLIST.
    JOB_ENV=$(echo "${JOB}" | awk -F "/" '{print $(NF?NF-1:0)}')
    # Make diff
    mkdir -p "${OUT_DIR}/diff/${JOB_ENV}"
    diff -U 50 "${OUT_DIR}/old/${JOB_ENV}/${JOB_NAME}" \
        "${OUT_DIR}/new/${JOB_ENV}/${JOB_NAME}" >> "${OUT_DIR}/diff/${JOB_ENV}/${JOB_NAME}" || true

    for BL in ${WORKSPACE}/servers/${JOB_ENV}/${BLOCKLIST}; do
      # Do exact job name match when checking with blocklist.
      GREP=$(grep -Fxq "${JOB_NAME}" "${BL}"; echo "${?}")
      if [[ ${GREP} -eq 0 ]]; then
        BLOCK=1
        BLOCKED+=${JOB_ENV}/${JOB_NAME}\<br\>
      # If grep returned 2 then there was no such blockfile.
      elif [[ ${GREP} -eq 2 ]]; then
        echo Error. There is no such blockfile.
        exit 2
      else
        CHANGE=1
        CHANGED+="<a href=${BUILD_URL}artifact/output/${TYPE}/diff/${JOB_ENV}/${JOB_NAME}/*view*/>${JOB_ENV}/${JOB_NAME}</a><br>"
      fi
    done
  done
  # Now find added/removed Jobs...
  for JOB in $(awk '/Only in/ {print $3$4}' "${LOGFILE}"); do
    ON=$(echo  "${JOB}"|awk -F/ '{print $8}')
    JOB_NAME=$(echo  "${JOB}"| awk -F: '{print $2}')
    JOB_ENV=$(echo "${JOB}" | awk -F "/" '{print $(NF?NF-0:0)}' | cut -f1 -d ':')
    if [[ ${ON} = 'old' ]]; then
      REMOVE=1
      REMOVED+="<a href=${BUILD_URL}artifact/output/${TYPE}/old/${JOB_ENV}/${JOB_NAME}/*view*/>${JOB_ENV}/${JOB_NAME}</a><br>"
    elif [[ ${ON} = 'new' ]]; then
      ADD=1
      ADDED+="<a href=${BUILD_URL}artifact/output/${TYPE}/new/${JOB_ENV}/${JOB_NAME}/*view*/>${JOB_ENV}/${JOB_NAME}</a><br>"
    fi
  done
fi

# Add section only if there're any changes found
if [ "$(( BLOCK + CHANGE + ADD + REMOVE ))" -gt 0 ]; then
  RESULT+="<br><b>$(tr "[:lower:]" "[:upper:]" <<< "${TYPE}"):</b><br>"
fi

# Print Blocked or Changed jobs.
if [[ ${BLOCK} -eq 1 ]]; then
  RESULT+=${BLOCKED}
elif [[ ${CHANGE} -eq 1 ]]; then
  RESULT+=${CHANGED}
fi
# And print added/removed if any.
if [[ ${REMOVE} -eq 1 ]]; then
  RESULT+=${REMOVED}
fi
if [[ ${ADD} -eq 1 ]]; then
  RESULT+=${ADDED}
fi
}

compare_xml "${JOBS_OUT_DIR}" "${JOBS_LOGFILE}" "jobs"
BLOCK_JOBS=${BLOCK}
compare_xml "${VIEWS_OUT_DIR}" "${VIEWS_LOGFILE}" "views"
BLOCK_VIEWS=${BLOCK}

echo "${RESULT#<br>}"

exit "$(( BLOCK_JOBS + BLOCK_VIEWS ))"
