#!/bin/bash

set -e

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

source ~/.envs/burrito/bin/activate
OFFLINE_VARS=
pushd ${CURRENT_DIR}/../
  if [ -f .offline_flag ] && \
    ${CURRENT_DIR}/offline_services.sh -s &>/dev/null; then
    OFFLINE_VARS="--extra-vars=@offline_vars.yml"
  fi
  ansible-playbook --extra-vars=@vars.yml ${OFFLINE_VARS} \
    ceph_purge.yml
popd
