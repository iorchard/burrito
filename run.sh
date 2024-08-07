#!/bin/bash

set -e 

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

function USAGE() {
  echo "USAGE: $0 [playbook_name] <ansible_parameters>" 1>&2
  echo
  echo "playbook_name"
  echo "============="
  echo "-- installation playbooks --"
  echo "vault       - create an ansible vault"
  echo "ping        - ping to all nodes"
  echo "preflight   - play common tasks, i.e. yum repo settings"
  echo "ceph        - play ceph tasks (when ceph in storage backend)"
  echo "ha          - play ha stack tasks, HAProxy/KeepAlived"
  echo "k8s         - play kubernetes installation tasks"
  echo "netapp      - play netapp tasks (when netapp in storage backend)"
  echo "powerflex   - play powerflex tasks (when powerflex in storage backend)"
  echo "hitachi     - play hitachi tasks (when hitachi in storage backend)"
  echo "primera     - play primera tasks (when primera in storage backend)"
  echo "lvm         - play lvm tasks (when lvm in storage backend)"
  echo "purestorage - play purestorage tasks (when purestorage in storage backend)"
  echo "patch       - play kubernetes security patch tasks"
  echo "registry    - play local registry tasks (offline only)"
  echo "landing     - play localrepo/genesisregistry tasks (offline only)"
  echo "burrito     - play openstack installation tasks"
  echo
  echo "-- operation playbooks --"
  echo "ceph_purge            - play ceph storage cluster purge tasks"
  echo "primera_uninstall     - play primera csi driver uninstall tasks"
  echo "purestorage_uninstall - play purestorage/portworx  uninstall tasks"
  echo "scale                 - play kubernetes node addition tasks"
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
OS_VARS=

[ -f /etc/os-release ] && . /etc/os-release || (echo 'Cannot find /etc/os-release'; exit 1)
[ -f ${ID}_vars.yml ] && OS_VARS="--extra-vars=@${ID}_vars.yml" || :

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
  ${OFFLINE_VARS} ${OS_VARS} ${FLAGS} ${PLAYBOOK}.yml
