#!/bin/bash

set -e

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

source ~/.envs/burrito/bin/activate
OFFLINE_VARS=
LEAP_VARS="leap_vars.yml"

pushd ${CURRENT_DIR}/../
  if [ -f .offline_flag ] && \
    ${CURRENT_DIR}/offline_services.sh -s &>/dev/null; then
    OFFLINE_VARS="--extra-vars=@offline_vars.yml"
  fi
  if [ -f ${LEAP_VARS} ]; then
    OFFLINE_VARS="${OFFLINE_VARS} --extra-vars=@${LEAP_VARS}"
  fi
  ansible-playbook --extra-vars=@vars.yml ${OFFLINE_VARS} \
    -b kubespray/reset.yml
popd

echo "Remove localrepo, registry haproxy conf files."
ansible --become kube_control_plane -m ansible.builtin.file \
  -a "path=/etc/haproxy/conf.d/localrepo.cfg state=absent"
ansible --become kube_control_plane -m ansible.builtin.file \
  -a "path=/etc/haproxy/conf.d/registry.cfg state=absent"
ansible --become kube_control_plane -m ansible.builtin.service \
  -a "name=haproxy.service state=reloaded"
