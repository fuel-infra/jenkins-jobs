#!/bin/bash

set -ex

if [ "${REBUILD}" == true ]; then
  MODE="--no-cache"
  echo "[ INFO ] Rebuild is called, setting --no-cache mode"
fi

OUTPUT="[urls]"

# prepare image list

IMAGES=$(git diff --name-only HEAD~1 \
  | awk -F "/" -vORS=" " \
  '/^[^\.]+\/[^\.]/ {if (!seen[$1$2]++) {print $1":"$2}}')

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

  echo "Cleaning a previous image first:"
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true

  # check if directory still exists
  if [[ -f "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}/Dockerfile" ]]
  then
    # build image
    echo "Building a new image from the URL:"
    cd "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}"
    docker build "${MODE}" -t "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" .
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
