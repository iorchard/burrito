#!/bin/bash

set -e 

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

function USAGE() {
  echo "USAGE: $0 [playbook_name] <ansible_parameters>" 1>&2
  echo
  echo "playbook_name"
  echo "============="
  echo "common     - play common tasks, i.e. yum repo settings."
  echo "ha         - play ha stack tasks, HAProxy/KeepAlived."
  echo "ceph       - play ceph installation tasks."
  echo "k8s        - play kubernetes installation tasks."
  echo "patch      - play kubernetes patch tasks."
  echo "registry   - play local registry image push tasks."
  echo "openstack  - play openstack installation tasks."
  echo
  echo "ansible_parameters"
  echo "=================="
  echo "ex) --tags=ceph-csi"
  echo 
}
if [ $# -lt 1 ]; then
  USAGE
  exit 1
fi

PLAYBOOK=$1
shift

OFFLINE_VARS=""
if [[ -f .offline_flag ]]; then
  # check offline services status
  if ${CURRENT_DIR}/scripts/offline_services.sh -s &>/dev/null; then
    OFFLINE_VARS="--extra-vars=@offline_vars.yml"
  else
    echo "There is a problem with offline services."
    echo "Run offline services - ${CURRENT_DIR}/scripts/offline_services.sh"
    ${CURRENT_DIR}/scripts/offline_services.sh -s
    exit 1
  fi
fi
[[ "${PLAYBOOK}" = "k8s" ]] && FLAGS="-b" || FLAGS=""
FLAGS="${FLAGS} $@"

if [[ "${PLAYBOOK}" = "burrito" ]]; then
  # install helm diff plugin
  HELM_DIFF_TARBALL="/mnt/files/github.com/databus23/helm-diff/releases/download/v3.6.0/helm-diff-linux-amd64.tgz"
  HELM_PLUGINS=$(helm env | grep HELM_PLUGINS |cut -d'"' -f2)
  mkdir -p ${HELM_PLUGINS}
  tar -C ${HELM_PLUGINS} -xzf ${HELM_DIFF_TARBALL}
  helm plugin list
fi

source ~/.envs/burrito/bin/activate
ansible-playbook --extra-vars=@vars.yml ${OFFLINE_VARS} ${FLAGS} ${PLAYBOOK}.yml
