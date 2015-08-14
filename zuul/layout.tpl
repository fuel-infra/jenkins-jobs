#
# Python code to set job parameters
#

includes:
  - python-file: external_functions.py

#
# Pipelines
#

pipelines:

  - name: pkg-build-mos
    description: |
      Newly uploaded patchsets enter this pipeline to get an initial
      +/-1 Verified vote from Jenkins.

      This pipeline is triggered when openstack/* projects gets +1 from
      Infra CI (mos-infra-ci), or comment "recheck".
    source: gerrit
    success-message: |
      Build succeeded (pkg-build pipeline).
    failure-message: |
      Build failed (pkg-build pipeline).
    manager: IndependentPipelineManager
    trigger:
      gerrit:
        - event: comment-added
          username: mos-infra-ci
          approval:
            - verified: 1
          branch:
            - ^master$
            - ^openstack-ci/fuel-[7-9]\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*(recheck|reverify)
          branch:
            - ^master$
            - ^openstack-ci/fuel-[7-9]\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 1
    failure:
      gerrit:
        verified: -1

  - name: pkg-build-spec
    description: |
      Newly uploaded patchsets enter this pipeline to get an initial
      +/-1 Verified vote from Jenkins.

      This pipeline created specially for openstack-build/* projects, because
      it use same branches as openstack/* projects, but never will get
      approvement from Infra CI (mos-infra-ci).

      So this job is triggerred by any new patchset to branch same as
      MOS projects, but attached only to openstack-build/* projects.
    source: gerrit
    success-message: |
      Build succeeded (pkg-build pipeline).
    failure-message: |
      Build failed (pkg-build pipeline).
    manager: IndependentPipelineManager
    trigger:
      gerrit:
        - event: patchset-created
          branch:
            - ^master$
            - ^openstack-ci/fuel-[7-9]\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*(recheck|reverify)
          branch:
            - ^master$
            - ^openstack-ci/fuel-[7-9]\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 1
    failure:
      gerrit:
        verified: -1

  - name: pkg-build-deps
    description: |
      Newly uploaded patchsets enter this pipeline to get an initial
      +/-1 Verified vote from Jenkins.

      This pipeline is triggered when project, that are required by openstack/*
      projects, gets new patchset or comment "recheck".
    source: gerrit
    success-message: |
      Build succeeded (pkg-build pipeline).
    failure-message: |
      Build failed (pkg-build pipeline).
    manager: IndependentPipelineManager
    trigger:
      gerrit:
        - event: patchset-created
          branch:
            - ^master$
            - ^[7-9]\.\d$
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*(recheck|reverify)
          branch:
            - ^master$
            - ^[7-9]\.\d$
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 1
    failure:
      gerrit:
        verified: -1

  - name: pkg-gate-release
    description: |
      Recheck approved changes and merge on success.

      This pipeline is triggerred only by changes to versioned branches to not mess changes from stable
      brances and master.
    source: gerrit
    success-message: |
      Build succeeded (pkg-gate pipeline).
    failure-message: |
      Build failed (pkg-gate pipeline).
    manager: DependentPipelineManager
    trigger:
      gerrit:
        - event: comment-added
          approval:
            - workflow: 1
          branch:
            - ^[7-9]\.\d$
            - ^openstack-ci/fuel-[7-9]\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 2
        submit: False
    failure:
      gerrit:
        verified: -2
    precedence: high
    window-floor: 20
    window-increase-factor: 2

  - name: pkg-gate-master
    description: |
      Recheck approved changes and merge on success.

      This pipeline is triggerred only by changes to master branch to not mess changes from master branch
      and stable brances.
    source: gerrit
    success-message: |
      Build succeeded (pkg-gate pipeline).
    failure-message: |
      Build failed (pkg-gate pipeline).
    manager: DependentPipelineManager
    trigger:
      gerrit:
        - event: comment-added
          approval:
            - workflow: 1
          branch:
            - ^master$
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 2
        submit: False
    failure:
      gerrit:
        verified: -2
    precedence: high
    window-floor: 20
    window-increase-factor: 2

  - name: pkg-publish
    description: |
      Build and publish released packages for merged changes.

      This branch is triggerred when merged change to any project that produces package.
    source: gerrit
    success-message: |
      Build succeeded (pkg-publish pipeline).
    failure-message: |
      Build failed (pkg-publish pipeline).
    manager: IndependentPipelineManager
    trigger:
      gerrit:
        - event: change-merged
          branch:
            - ^master$
            - ^[7-9]\.\d$
            - ^openstack-ci/fuel-[7-9]\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
    require:
      status: MERGED
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 0
    failure:
      gerrit:
        verified: 0

  - name: merge-check
    description: Each time a change merges, this pipeline verifies that all open changes on the same project are still mergeable.
    failure-message: Build failed (merge-check pipeline).
    manager: IndependentPipelineManager
    source: gerrit
    precedence: low
    trigger:
      zuul:
        - event: project-change-merged
    merge-failure:
      gerrit:
        verified: 0

#
# Jobs
#

jobs:

  - name: ^pkg-(build|gate|publish)-.+-deb$
    parameter-function: pkg_build
    voting: False
    skip-if:
      - project: ^packages/centos\d/
      - branch: ^openstack-ci/fuel/centos\d/

  - name: ^pkg-(build|gate|publish)-.+-rpm$
    parameter-function: pkg_build
    voting: False
    skip-if:
      - project: ^packages/trusty/
      - project: ^openstack(-build)?/
        branch: ^master$
      - project: ^openstack(-build)?/
        branch: ^openstack-ci/fuel-[7-9]\.\d[-/]

#
# Project templates
#

project-templates:

  - name: openstack
    merge-check:
      - noop
    pkg-build-mos:
      - pkg-build-7.0-deb
      - pkg-build-7.0-rpm
    pkg-gate-release:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-gate-master:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-publish:
      - pkg-publish-7.0-deb
      - pkg-publish-7.0-rpm

  - name: spec
    merge-check:
      - noop
    pkg-build-spec:
      - pkg-build-7.0-deb
      - pkg-build-7.0-rpm
    pkg-gate-release:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-gate-master:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-publish:
      - pkg-publish-7.0-deb
      - pkg-publish-7.0-rpm

  - name: deps
    merge-check:
      - noop
    pkg-build-deps:
      - pkg-build-7.0-deb
      - pkg-build-7.0-rpm
    pkg-gate-release:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-gate-master:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-publish:
      - pkg-publish-7.0-deb
      - pkg-publish-7.0-rpm

#
# Projects
#

projects:
  - name: fuel-infra/ci-sandbox
    merge-check:
      - noop
    pkg-build-deps: 
      - pkg-build-7.0-deb
      - pkg-build-7.0-rpm
    pkg-gate-release:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-gate-master:
      - pkg-gate-7.0-deb
      - pkg-gate-7.0-rpm
    pkg-publish:
      - pkg-publish-7.0-deb
      - pkg-publish-7.0-rpm
