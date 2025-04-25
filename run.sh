#!/bin/bash

set -e 

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

function USAGE() {
cat <<EOF 1>&2
USAGE: $0 [playbook_name] <ansible_parameters>

playbook_name
=============
-- installation playbooks --
vault       	- create an ansible vault
ping        	- ping to all nodes
preflight   	- play common tasks, i.e. repo settings
ha          	- play ha stack tasks, HAProxy/KeepAlived
ceph        	- play ceph tasks (when ceph in storage backend)
powerflex_pfmp	- play powerflex pfmp tasks (when powerflex in storage backend)
k8s         	- play kubernetes installation tasks
storage     	- play k8s storage csi tasks
powerflex_csi	- play powerflex csi tasks (when powerflex in storage backend)
patch       	- play kubernetes security patch tasks
registry    	- play local registry tasks (offline only)
landing     	- play localrepo/genesisregistry tasks (offline only)
burrito     	- play openstack installation tasks

-- operation playbooks --
ceph_purge            - play ceph storage cluster purge tasks
primera_uninstall     - play primera csi driver uninstall tasks
purestorage_uninstall - play purestorage/portworx  uninstall tasks
scale                 - play kubernetes node addition tasks

ansible_parameters
==================
ex) --tags=ceph-csi
EOF
}
if [ $# -lt 1 ]; then
  USAGE
  exit 1
fi

PLAYBOOK=$1
shift

OFFLINE_VARS=
OS_VARS=
HELMDIFF=

[ -f /etc/os-release ] && . /etc/os-release || (echo 'Cannot find /etc/os-release.' 1>&2; exit 1)
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
if [[ "${PLAYBOOK}" = "ceph_purge" ]]; then
  if [ -f .offline_flag ]; then
    OFFLINE_VARS="--extra-vars=@offline_vars.yml"
  fi
  . ~/.envs/burrito/bin/activate
  ansible-playbook --user=${USER} --extra-vars=@vars.yml \
    ${OFFLINE_VARS} ${OS_VARS} ${FLAGS} ${PLAYBOOK}.yml
  exit 0
fi
if [ -f .offline_flag ]; then
  # check offline services status
  if ${CURRENT_DIR}/scripts/offline_services.sh -s &>/dev/null; then
    OFFLINE_VARS="--extra-vars=@offline_vars.yml"
  else
    cat <<EOF 1>&2

Abort) The offline flag is up but offline services are not up.
Run offline services before running ${PLAYBOOK}
(${CURRENT_DIR}/scripts/offline_services.sh -u).

EOF
    ${CURRENT_DIR}/scripts/offline_services.sh -s
    exit 1
  fi
fi
[[ "${PLAYBOOK}" = "k8s" || "${PLAYBOOK}" = "scale" ]] && FLAGS="-b" || FLAGS=
FLAGS="${FLAGS} $@"

[[ "${PLAYBOOK}" = "scale" ]] && PLAYBOOK="kubespray/${PLAYBOOK}" || :
[[ "${PLAYBOOK}" = "k8s" ]] && PLAYBOOK="kubespray/cluster" || :
if type -p helm &>/dev/null; then
  HELMDIFF="1"
fi
if [[ -n "${HELMDIFF}" && -n "${OFFLINE_VARS}" ]]; then
  if ! (sudo helm plugin list | grep -q ^diff); then
    # install helm diff plugin
    HELM_DIFF_TARBALL="/mnt/files/github.com/databus23/helm-diff/releases/download/*/helm-diff-linux-amd64.tgz"
    HELM_PLUGINS=$(sudo helm env | grep HELM_PLUGINS |cut -d'"' -f2)
    sudo mkdir -p ${HELM_PLUGINS}
    sudo tar -C ${HELM_PLUGINS} -xzf ${HELM_DIFF_TARBALL}
    sudo chown -R root:root ${HELM_PLUGINS}
    sudo helm plugin list
  fi
fi

. ~/.envs/burrito/bin/activate
ansible-playbook --user=${USER} --extra-vars=@vars.yml \
  ${OFFLINE_VARS} ${OS_VARS} ${FLAGS} ${PLAYBOOK}.yml
