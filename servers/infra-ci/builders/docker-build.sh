#!/bin/bash

set -ex

OUTPUT="[urls]"

# prepare prefix
if [ "${GERRIT_EVENT_TYPE}" == 'change-merged' ]
then
  PREFIX='infra'
else
  PREFIX='jenkins'
fi

# prepare image list
IMAGES=$(git diff --name-only HEAD~1 \
  | grep Dockerfile \
  | sed 's/\/Dockerfile//g' \
  | sed 's/\//:/g' \
  | tr '\n' ' ')

# build all images
for IMAGE in ${IMAGES}
do
  IMAGE_NAME=$(echo "$IMAGE" | cut -f 1 -d :)
  IMAGE_TAG=$(echo "$IMAGE" | cut -f 2 -d :)

  echo "Cleaning a previous image first:"
  docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || /bin/true

  # check if directory still exists
  if [ -f "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}/Dockerfile" ]
  then
    # build image
    echo "Building a new image from the URL:"
    cd "${WORKSPACE}/${IMAGE_NAME}/${IMAGE_TAG}"
    docker build -t "${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}" .
    # add image to publish list
    VIMAGES="${VIMAGES} ${IMAGE_NAME}:${IMAGE_TAG}"
    OUTPUT+="${PREFIX}/${IMAGE_NAME}:${IMAGE_TAG}<br>"
  fi
done

# remove trailing, leading spaces
IMAGES=$(echo -e "${VIMAGES}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# prepare artifacts for publisher
echo "PREFIX='${PREFIX}'" > "${WORKSPACE}/to_publish.txt"
echo "IMAGES='${IMAGES}'" >> "${WORKSPACE}/to_publish.txt"

echo "${OUTPUT}"
