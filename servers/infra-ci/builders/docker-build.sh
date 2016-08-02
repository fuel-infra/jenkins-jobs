#!/bin/bash

set -ex

FILTER="."

if [ "${REBUILD}" == "true" ]; then
  MODE="--no-cache"
  echo "[ INFO ] Rebuild is called, setting --no-cache mode"
fi

if [ "${ACTION}" == "verify-fuel-ci" ]; then
  FILTER="fuel-ci-tests"
fi

IMAGES=$(git diff --name-only HEAD~1 \
  | egrep "${FILTER}" \
  | awk -F "/" -vORS=" " \
  '/^[^\.]+\/[^\.]/ {if (!seen[$1$2]++) {print $1":"$2}}')

OUTPUT="[urls]"

# build all images
for IMAGE in ${IMAGES}
do
  IMAGE_NAME=$(echo "$IMAGE" | cut -f 1 -d :)
  IMAGE_TAG=$(echo "$IMAGE" | cut -f 2 -d :)

  # prepare prefix
  if [[ -z "${FORCE_PREFIX}" ]]
  then
    # if no prefix defined - use router to get prefix
    while read RULE
    do
      #convert string to array
      RULE=($RULE)
      # skip if commented or empty
      if [[ "${RULE[0]}" =~ ^# ]] || [[ "${RULE[0]}" =~ ^$ ]]; then continue; fi
      # check if matches the rule
      if [[ "${IMAGE_NAME}" =~ ${RULE[0]} ]]
      then
        # set prefix and stop checking other rules
        PREFIX="${RULE[1]}"
        break
      fi
    done < router.cfg
  else
    # if prefix is defined - use it for every image
    PREFIX="${FORCE_PREFIX}"
  fi

  echo "[ STATUS ] Cleaning a previous image first:"
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true

  # check if directory still exists
  if [[ -f "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}/Dockerfile" ]]
  then
    # build image
    echo "[ STATUS ] Building a new image from the URL:"
    cd "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}"
    docker build ${MODE} -t "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" .
    if [ "${ACTION}" == "verify-fuel-ci" ]; then
      # Container ID path
      CONTAINER_ID="${WORKSPACE}/container.id"
      # Path to runner script inside Docker image
      SCRIPT_PATH="/opt/jenkins/runner.sh"

      # run default tests
      echo "[ STATUS ] Fuel CI image verification started."
      docker run --cidfile="${CONTAINER_ID}" \
                 -t "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" \
                 /bin/bash -exc "${SCRIPT_PATH} verify_image"
      exitcode=$?
      # stop container
      docker stop "$(cat "${CONTAINER_ID}")"
      echo "[ STATUS ] Docker exit code was ${exitcode}"
    else
      echo "[ STATUS ] Non Fuel CI image, verification skipped."
    fi
    # add image to publish list
    VIMAGES="${VIMAGES} ${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}"
    OUTPUT+="${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}<br>"
  fi
done

# remove trailing, leading spaces
IMAGES=$(echo -e "${VIMAGES}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# prepare artifacts for publisher
echo "IMAGES='${IMAGES}'" > "${WORKSPACE}/publish_env.sh"

echo "${OUTPUT}"
