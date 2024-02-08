#!/bin/bash

set -e

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

TOP_PATH=${CURRENT_DIR}/..

declare -A d_tag=(
  [calico]="network,policy-controller"
  [coredns]="coredns"
  [metallb]="metallb"
  [registry]="registry"
)
display_help() {
  echo "Usage: $0 <k8s_component>" >&2
  echo "    <component>"
  echo "    calico, coredns, metallb, registry"
}
install() {
  if [ ! ${d_tag[$NAME]} ]; then
    echo "Unknown name: $NAME"
    display_help
    exit 1
  fi
  # copy k8s_app.yml to kubespray
  cp ${CURRENT_DIR}/k8s_app.yml \
    ${TOP_PATH}/kubespray/playbooks/k8s_app.yml
  . ~/.envs/burrito/bin/activate
  pushd ${CURRENT_DIR}/../
    OFFLINE_VARS=
    if [ -f .offline_flag ] && \
      ${CURRENT_DIR}/offline_services.sh -s &>/dev/null; then
      OFFLINE_VARS="--extra-vars=@offline_vars.yml"
    fi
    ansible-playbook --user=${USER} -b --extra-vars=@vars.yml \
        ${OFFLINE_VARS} --tags=${d_tag[$NAME]} \
        ${TOP_PATH}/kubespray/playbooks/k8s_app.yml
    rm -f ${TOP_PATH}/kubespray/playbooks/k8s_app.yml
  popd
}

if [ $# -lt 1 ]
then
  display_help
  exit 0
fi
NAME=$1

install
