#!/bin/bash

set -e 

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

function USAGE() {
  echo "USAGE: $0 [playbook_name] <ansible_parameters>" 1>&2
  echo
  echo "playbook_name"
  echo "============="
  echo "vault     - create an ansible vault."
  echo "ping      - ping to all nodes."
  echo "preflight - play common tasks, i.e. yum repo settings."
  echo "ha        - play ha stack tasks, HAProxy/KeepAlived."
  echo "ceph      - play ceph tasks. (when ceph in storage backend)"
  echo "k8s       - play kubernetes installation tasks."
  echo "netapp    - play netapp tasks. (when netapp in storage backend)"
  echo "powerflex - play powerflex tasks. (when powerflex in storage backend)"
  echo "hitachi   - play hitachi tasks. (when hitachi in storage backend)"
  echo "primera   - play primera tasks. (when primera in storage backend)"
  echo "patch     - play kubernetes security patch tasks."
  echo "registry  - play local registry setup tasks. (offline install only)"
  echo "landing   - play localrepo/genesis registry setup tasks."
  echo "burrito   - play openstack installation tasks."
  echo "scale     - play kubernetes node addition tasks."
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

OFFLINE_VARS=

if [[ "${PLAYBOOK}" = "vault" ]]; then
  . ~/.envs/burrito/bin/activate
  ${CURRENT_DIR}/vault.sh
  exit 0
fi
if [[ "${PLAYBOOK}" = "ping" ]]; then
  . ~/.envs/burrito/bin/activate
  ansible -m ping --extra-vars=@vars.yml all
  exit 0
fi
if [ -f .offline_flag ]; then
  # check offline services status
  if ${CURRENT_DIR}/scripts/offline_services.sh -s &>/dev/null; then
    OFFLINE_VARS="--extra-vars=@offline_vars.yml"
  else
    echo "The offline flag is up but offline services are not up."
    echo "Run offline services - ${CURRENT_DIR}/scripts/offline_services.sh -u"
    ${CURRENT_DIR}/scripts/offline_services.sh -s
    exit 1
  fi
fi
[[ "${PLAYBOOK}" = "k8s" || "${PLAYBOOK}" = "scale" ]] && FLAGS="-b" || FLAGS=
FLAGS="${FLAGS} $@"

[[ "${PLAYBOOK}" = "scale" ]] && PLAYBOOK="kubespray/${PLAYBOOK}" || :
[[ "${PLAYBOOK}" = "k8s" ]] && PLAYBOOK="kubespray/cluster" || :

if [[ "${PLAYBOOK}" = "burrito" && -n ${OFFLINE_VARS} ]]; then
  if ! (helm plugin list | grep -q ^diff); then
    # install helm diff plugin
    HELM_DIFF_TARBALL="/mnt/files/github.com/databus23/helm-diff/releases/download/*/helm-diff-linux-amd64.tgz"
    HELM_PLUGINS=$(sudo helm env | grep HELM_PLUGINS |cut -d'"' -f2)
    sudo mkdir -p ${HELM_PLUGINS}
    sudo tar -C ${HELM_PLUGINS} -xzf ${HELM_DIFF_TARBALL}
  fi
  sudo helm plugin list
fi

. ~/.envs/burrito/bin/activate
ansible-playbook --user=${USER} --extra-vars=@vars.yml \
  ${OFFLINE_VARS} ${FLAGS} ${PLAYBOOK}.yml
