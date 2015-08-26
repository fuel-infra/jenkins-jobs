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
      Infra CI (mos-infra-ci), or comment "rebuild".
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
#            - ^master$
            - ^openstack-ci/fuel-8\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*rebuild
          branch:
#            - ^master$
            - ^openstack-ci/fuel-8\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          approval:
            - workflow: 1
          require-approval:
            - verified: [-1, -2]
              username: pkgs-ci
          branch:
#            - ^master$
            - ^openstack-ci/fuel-8\.\d[-/]
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
#            - ^master$
            - ^openstack-ci/fuel-8\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*rebuild
          branch:
#            - ^master$
            - ^openstack-ci/fuel-8\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          approval:
            - workflow: 1
          require-approval:
            - verified: [-1, -2]
              username: pkgs-ci
          branch:
#            - ^master$
            - ^openstack-ci/fuel-8\.\d[-/]
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
      projects, gets new patchset or comment "rebuild".
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
#            - ^master$
            - ^8\.\d$
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*rebuild
          branch:
#            - ^master$
            - ^8\.\d$
        - event: comment-added
          approval:
            - workflow: 1
          require-approval:
            - verified: [-1, -2]
              username: pkgs-ci
          branch:
#            - ^master$
            - ^8\.\d$
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

  - name: pkg-test
    description: |
      Run package tests and set Verified +/- 2 vote

      This pipeline is triggered when project, gets Verified +1 from user pkgs-ci
      or by comment "retest".
    source: gerrit
    success-message: |
      Build succeeded (pkg-build pipeline).
    failure-message: |
      Build failed (pkg-build pipeline).
    manager: IndependentPipelineManager
    trigger:
      gerrit:
        - event: comment-added
          username: pkgs-ci
          approval:
            - verified: 1
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*retest
          branch:
            - ^master$
            - ^8\.\d$
            - ^openstack-ci/fuel-8\.\d[-/]
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
    failure:
      gerrit:
        verified: -2

  - name: pkg-gate
    description: |
      Recheck approved changes and merge on success.
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
#            - ^master$
            - ^8\.\d$
            - ^openstack-ci/fuel-8\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          approval:
            - verified: 1
          username: pkgs-ci
    require:
      current-patchset: True
      open: True
      approval:
        - verified: [1, 2]
          username: pkgs-ci
        - workflow: 1
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 2
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
#            - ^master$
            - ^8\.\d$
            - ^openstack-ci/fuel-8\.\d[-/]
            - ^openstack-ci/fuel/centos\d/
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*(re)?publish
          branch:
#            - ^master$
            - ^8\.\d$
            - ^openstack-ci/fuel-8\.\d[-/]
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

  - name: ^8.0-pkg-(pipeline|gate|publish)-centos$
    queue-name: mos-8.0-centos
    branch:
      - ^8\.\d$
      - ^openstack-ci/fuel-8\.\d[-/]
      - ^openstack-ci/fuel/centos\d/
    parameter-function: pkg_build
    voting: False
    skip-if:
      - project: ^packages/debian/
      - project: ^packages/trusty/
      - project: ^openstack/deb-
      - project: ^openstack-build/
        all-files-match-any:
          - ^debian/
          - ^trusty/debian/

  - name: ^8.0-pkg-(pipeline|gate|publish)-debian$
    queue-name: mos-8.0-debian
    branch: non-existent
    # Upstream have another naming for source and spec projects for Debian packages
    parameter-function: pkg_build_debian
    voting: True
    skip-if:
      - project: ^packages/centos\d/
      - project: ^packages/trusty/
      - project: ^openstack-build/

  - name: ^8.0-pkg-(pipeline|gate|publish)-ubuntu$
    queue-name: mos-8.0-ubuntu
    branch:
      - ^8\.\d$
      - ^openstack-ci/fuel-8\.\d[-/]
    parameter-function: pkg_build
    voting: True
    skip-if:
      - project: ^packages/centos\d/
      - project: ^packages/debian/
      - project: ^openstack/deb-
      - project: ^openstack-build/
        all-files-match-any:
          - ^rpm/

  - name: ^master-pkg-(pipeline|gate|publish)-centos$
    queue-name: mos-master-centos
    branch: ^master$
    parameter-function: pkg_build
    voting: False
    skip-if:
      - project: ^packages/debian/
      - project: ^packages/trusty/
      - project: ^openstack/deb-
      - project: ^openstack-build/
        all-files-match-any:
          - ^debian/
          - ^trusty/debian/

  - name: ^master-pkg-(pipeline|gate|publish)-debian$
    queue-name: mos-master-debian
    branch: non-existent
    # Upstream have another naming for source and spec projects for Debian packages
    parameter-function: pkg_build_debian
    voting: True
    skip-if:
      - project: ^packages/centos\d/
      - project: ^packages/trusty/
      - project: ^openstack-build/

  - name: ^master-pkg-(pipeline|gate|publish)-ubuntu$
    queue-name: mos-master-ubuntu
    branch: ^master$
    parameter-function: pkg_build
    voting: True
    skip-if:
      - project: ^packages/centos\d/
      - project: ^packages/debian/
      - project: ^openstack/deb-
      - project: ^openstack-build/
        all-files-match-any:
          - ^rpm/

#
# Project templates
#

project-templates:

  - name: openstack
    merge-check:
      - noop
    pkg-build-mos:
      - 8.0-pkg-pipeline-centos
      - 8.0-pkg-pipeline-debian
      - 8.0-pkg-pipeline-ubuntu
      - master-pkg-pipeline-centos
      - master-pkg-pipeline-debian
      - master-pkg-pipeline-ubuntu
    pkg-gate:
      - 8.0-pkg-gate-centos
      - 8.0-pkg-gate-debian
      - 8.0-pkg-gate-ubuntu
      - master-pkg-gate-centos
      - master-pkg-gate-debian
      - master-pkg-gate-ubuntu
    pkg-publish:
      - 8.0-pkg-pipeline-centos
      - 8.0-pkg-pipeline-debian
      - 8.0-pkg-pipeline-ubuntu
      - master-pkg-pipeline-centos
      - master-pkg-pipeline-debian
      - master-pkg-pipeline-ubuntu

  - name: spec
    merge-check:
      - noop
    pkg-build-spec:
      - 8.0-pkg-pipeline-centos
      - 8.0-pkg-pipeline-debian
      - 8.0-pkg-pipeline-ubuntu
      - master-pkg-pipeline-centos
      - master-pkg-pipeline-debian
      - master-pkg-pipeline-ubuntu
    pkg-gate:
      - 8.0-pkg-gate-centos
      - 8.0-pkg-gate-debian
      - 8.0-pkg-gate-ubuntu
      - master-pkg-gate-centos
      - master-pkg-gate-debian
      - master-pkg-gate-ubuntu
    pkg-publish:
      - 8.0-pkg-pipeline-centos
      - 8.0-pkg-pipeline-debian
      - 8.0-pkg-pipeline-ubuntu
      - master-pkg-pipeline-centos
      - master-pkg-pipeline-debian
      - master-pkg-pipeline-ubuntu

  - name: deps
    merge-check:
      - noop
    pkg-build-deps:
      - 8.0-pkg-pipeline-centos
      - 8.0-pkg-pipeline-debian
      - 8.0-pkg-pipeline-ubuntu
      - master-pkg-pipeline-centos
      - master-pkg-pipeline-debian
      - master-pkg-pipeline-ubuntu
    pkg-gate:
      - 8.0-pkg-gate-centos
      - 8.0-pkg-gate-debian
      - 8.0-pkg-gate-ubuntu
      - master-pkg-gate-centos
      - master-pkg-gate-debian
      - master-pkg-gate-ubuntu
    pkg-publish:
      - 8.0-pkg-pipeline-centos
      - 8.0-pkg-pipeline-debian
      - 8.0-pkg-pipeline-ubuntu
      - master-pkg-pipeline-centos
      - master-pkg-pipeline-debian
      - master-pkg-pipeline-ubuntu

#
# Projects
#

projects:

  - name: fuel-infra/ci-sandbox
    template:
      - name: deps
