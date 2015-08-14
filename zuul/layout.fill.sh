#!/bin/bash -e

CONFIG_PATH=/etc/zuul/layout
ZUUL_LAYOUT=${CONFIG_PATH}/layout.yaml

GERRIT_HOST=${GERRIT_HOST:-review.fuel-infra.org}
GERRIT_PORT=${GERRIT_PORT:-29418}
GERRIT_USER=${GERRIT_USER:-pkgs-ci}
GERRIT_KEY=${GERRIT_KEY:-/var/lib/zuul/ssh/id_rsa}

TMP_LAYOUT=$(mktemp)

cat ${CONFIG_PATH}/layout.tpl > ${TMP_LAYOUT}

# Openstack projects
PROJECTS="$(ssh -p ${GERRIT_PORT} -i ${GERRIT_KEY} ${GERRIT_USER}@${GERRIT_HOST} gerrit ls-projects --prefix openstack/)"

for project in $(echo "${PROJECTS}" | sort); do
cat <<EOF

  - name: ${project}
    template:
      - name: openstack
EOF
done >> ${TMP_LAYOUT}

# Build spec projects
PROJECTS="$(ssh -p ${GERRIT_PORT} -i ${GERRIT_KEY} ${GERRIT_USER}@${GERRIT_HOST} gerrit ls-projects --prefix openstack-build/)"

for project in $(echo "${PROJECTS}" | sort); do
cat <<EOF

  - name: ${project}
    template:
      - name: spec
EOF
done >> ${TMP_LAYOUT}

# Dependencies for OpenStack
PROJECTS="$(ssh -p ${GERRIT_PORT} -i ${GERRIT_KEY} ${GERRIT_USER}@${GERRIT_HOST} gerrit ls-projects --prefix packages/)"

for project in $(echo "${PROJECTS}" | sort); do
cat <<EOF

  - name: ${project}
    template:
      - name: deps
EOF
done >> ${TMP_LAYOUT}

test -f ${ZUUL_LAYOUT} && cp -f ${ZUUL_LAYOUT} ${ZUUL_LAYOUT}.bak
cp -f ${TMP_LAYOUT} ${ZUUL_LAYOUT}
rm -f ${TMP_LAYOUT}
