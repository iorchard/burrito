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
  echo "k8s       - play kubernetes installation tasks."
  echo
  echo "ansible_parameters"
  echo "=================="
  echo "ex) --tags=some_tag"
  echo 
}
if [ $# -lt 1 ]; then
  USAGE
  exit 1
fi

PLAYBOOK=$1
shift

OFFLINE_VARS=
LEAP_VARS="leap_vars.yml"

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
if [ "${PLAYBOOK}" = "k8s" -a ! -f ${LEAP_VARS} ]; then
  echo "${LEAP_VARS} is not found. Did you run the leap playbook?"
  exit 1
fi
[[ "${PLAYBOOK}" = "k8s" ]] && FLAGS="-b --extra-vars=@${LEAP_VARS}" || FLAGS=
FLAGS="${FLAGS} $@"

[[ "${PLAYBOOK}" = "k8s" ]] && PLAYBOOK="kubespray/cluster" || :

. ~/.envs/burrito/bin/activate
ansible-playbook --user=${USER} --extra-vars=@vars.yml \
  ${OFFLINE_VARS} ${FLAGS} ${PLAYBOOK}.yml
