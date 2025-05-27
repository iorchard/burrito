#!/bin/bash

set -e

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )

OSH_INFRA="osh_infra"
OSH="osh"
BTX="btx"
TOP_PATH=${CURRENT_DIR}/..
OVERRIDE_PATH=$HOME/openstack-artifacts

declare -A path_arr=(
  [ingress]=$OSH_INFRA
  [ceph-provisioners]=$OSH_INFRA
  [mariadb]=$OSH_INFRA
  [rabbitmq]=$OSH_INFRA
  [memcached]=$OSH_INFRA
  [openvswitch]=$OSH_INFRA
  [ovn]=$OSH_INFRA
  [libvirt]=$OSH_INFRA

  [keystone]=$OSH
  [glance]=$OSH
  [placement]=$OSH
  [neutron]=$OSH
  [nova]=$OSH
  [cinder]=$OSH
  [horizon]=$OSH
  [barbican]=$OSH

  [btx]=$BTX
)
display_help() {
  echo "Usage: $0 <action> <chart_name>" >&2
  echo "    <action>: install, uninstall"
  echo "    <chart_name>"
  echo "    ingress, ceph-provisioners, mariadb, rabbitmq, memcached"
  echo "    openvswitch, ovn, libvirt, keystone, glance, placement"
  echo "    neutron, nova, cinder, horizon, barbican, btx"

}
install() {
  # check the group - osh-infra, osh, btx
  TAG_OPTS="--tags=openstack"
  KEY=""
  if [ x"${path_arr[$NAME]}" = x"$OSH_INFRA" ]; then
    TAG_OPTS="${TAG_OPTS},osh-infra --skip-tags=osh,btx"
    KEY="osh_infra_charts"
  elif [ x"${path_arr[$NAME]}" = x"$OSH" ]; then
    TAG_OPTS="${TAG_OPTS},osh --skip-tags=osh-infra,btx"
    KEY="osh_charts"
  elif [ x"${path_arr[$NAME]}" = x"$BTX" ]; then
    TAG_OPTS="${TAG_OPTS},btx --skip-tags=osh-infra,osh"
    KEY="btx_charts"
  else
    echo "Unknown name: $NAME"
    display_help
    exit 1
  fi
  source ~/.envs/burrito/bin/activate
  pushd ${CURRENT_DIR}/../
    OFFLINE_VARS=
    if [ -f .offline_flag ] && \
      ${CURRENT_DIR}/offline_services.sh -s &>/dev/null; then
      OFFLINE_VARS="--extra-vars=@offline_vars.yml"
    fi
    ansible-playbook --extra-vars=@vars.yml ${OFFLINE_VARS} \
        --extra-vars="{\"$KEY\": [\"${NAME}\"]}" \
        ${TAG_OPTS} \
        ${TOP_PATH}/burrito.yml
  popd
}
uninstall() {
  set +e
  sudo helm uninstall ${NAME} --namespace=openstack
  sudo kubectl --namespace=openstack delete jobs,pods -l application=${NAME}
  set -e
}

if [ $# -lt 2 ]
then
  display_help
  exit 0
fi
ACTION=$1
NAME=$2

while :
do
  case $ACTION in
    install)
      install
      exit 0
      ;;
    uninstall)
      uninstall
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $ACTION" >&2
      exit 1
      ;;
  esac
done
