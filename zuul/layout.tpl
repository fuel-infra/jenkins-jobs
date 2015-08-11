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
      Newly uploaded patchsets enter this pipeline to get an initial +/-1 Verified vote from Jenkins.

      This pipeline is triggered when openstack/* projects gets +1 from Infra CI (mos-infra-ci), or
      when any other project gets new patchset or comment "recheck".
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
            - '^openstack-ci/fuel-7\.0[-/]'
            - '^master$'
        - event: patchset-created
          branch:
            - '^7\.0$'
            - '^master$'
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*(recheck|reverify)
          branch:
            - '^7\.0$'
            - '^master$'
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 0
    failure:
      gerrit:
        verified: 0

  - name: pkg-build-spec
    description: |
      Newly uploaded patchsets enter this pipeline to get an initial +/-1 Verified vote from Jenkins.

      This pipeline created specially for openstack-build/* projects, because they use same branches
      as openstack/* projects, but never will get approvement from Infra CI (mos-infra-ci).

      So this job is triggerred by any new patchset to branch same as MOS projects, but attached only
      to openstack-build/* projects.
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
            - '^openstack-ci/fuel-7\.0[-/]'
            - '^master$'
        - event: comment-added
          comment: (?i)^(Patch Set [0-9]+:)?( [\w\\+-]*)*(\n\n)?\s*(recheck|reverify)
          branch:
            - '^openstack-ci/fuel-7\.0[-/]'
            - '^master$'
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 0
    failure:
      gerrit:
        verified: 0

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
            - '^7\.0$'
            - '^openstack-ci/fuel-7\.0[-/]'
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 0
        submit: False
    failure:
      gerrit:
        verified: 0
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
            - '^master$'
    require:
      current-patchset: True
      open: True
    start:
      gerrit:
        verified: 0
    success:
      gerrit:
        verified: 0
        submit: False
    failure:
      gerrit:
        verified: 0
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
            - '^7\.0$'
            - '^master$'
            - '^openstack-ci/fuel-7\.0[-/]'
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

  - name: ^pkg-(build|gate|publish)-.+$
    parameter-function: pkg_build
    voting: False

#
# Project templates
#

project-templates:

  - name: openstack
    merge-check:
      - noop
    pkg-build-mos:
      - 'pkg-build-7.0-deb'
    pkg-gate-release:
      - 'pkg-gate-7.0-deb'
    pkg-gate-master:
      - 'pkg-gate-7.0-deb'
    pkg-publish:
      - 'pkg-publish-7.0-deb'

  - name: spec
    merge-check:
      - noop
    pkg-build-spec:
      - 'pkg-build-7.0-deb'
    pkg-gate-release:
      - 'pkg-gate-7.0-deb'
    pkg-gate-master:
      - 'pkg-gate-7.0-deb'
    pkg-publish:
      - 'pkg-publish-7.0-deb'

  - name: deps
    merge-check:
      - noop
    pkg-build-mos:
      - 'pkg-build-7.0-deb'
    pkg-gate-release:
      - 'pkg-gate-7.0-deb'
    pkg-gate-master:
      - 'pkg-gate-7.0-deb'
    pkg-publish:
      - 'pkg-publish-7.0-deb'

  - name: fuel
    merge-check:
      - noop
    pkg-build-mos:
      - 'pkg-build-7.0-rpm'
    pkg-gate-release:
      - 'pkg-gate-7.0-rpm'
    pkg-gate-master:
      - 'pkg-gate-7.0-rpm'
    pkg-publish:
      - 'pkg-publish-7.0-rpm'

#
# Projects
#

projects:
