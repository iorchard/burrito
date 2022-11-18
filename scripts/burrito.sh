#!/bin/bash

set -e

export OSH_INFRA_PATH=$HOME/burrito/openstack-helm-infra
export OSH_PATH=$HOME/burrito/openstack-helm
export BTX_PATH=$HOME/burrito/btx/helm
export OVERRIDE_PATH=$HOME/openstack-artifacts

declare -A path_arr=(
  [ingress]=$OSH_INFRA_PATH
  [ceph-provisioners]=$OSH_INFRA_PATH
  [mariadb]=$OSH_INFRA_PATH
  [rabbitmq]=$OSH_INFRA_PATH
  [memcached]=$OSH_INFRA_PATH
  [openvswitch]=$OSH_INFRA_PATH
  [libvirt]=$OSH_INFRA_PATH

  [keystone]=$OSH_PATH
  [glance]=$OSH_PATH
  [placement]=$OSH_PATH
  [neutron]=$OSH_PATH
  [nova]=$OSH_PATH
  [cinder]=$OSH_PATH
  [horizon]=$OSH_PATH

  [btx]=$BTX_PATH
)
display_help() {
  echo "Usage: $0 <action> <chart_name>" >&2
  echo "    <action>: install, uninstall"
  echo "    <chart_name>"
  echo "    ingress, ceph-provisioners, mariadb, rabbitmq, memcached"
  echo "    openvswitch, libvirt, keystone, glance, placement"
  echo "    neutron, nova, cinder, horizon, btx"

}
install() {
  sudo helm upgrade --install ${NAME} \
    ${path_arr[$NAME]}/${NAME} --namespace=openstack \
    --values=${OVERRIDE_PATH}/${NAME}.yml
}
uninstall() {
  sudo helm uninstall ${NAME} --namespace=openstack
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


