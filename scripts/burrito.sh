#!/bin/bash

set -e

OSH_INFRA_PATH=$HOME/burrito/openstack-helm-infra
OSH_PATH=$HOME/burrito/openstack-helm
BTX_PATH=$HOME/burrito/btx/helm
OVERRIDE_PATH=$HOME/openstack-artifacts
KUBESPRAY_PATH=$HOME/burrito/kubespray

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
  [barbican]=$OSH_PATH

  [btx]=$BTX_PATH
)
display_help() {
  echo "Usage: $0 <action> <chart_name>" >&2
  echo "    <action>: install, uninstall"
  echo "    <chart_name>"
  echo "    ingress, ceph-provisioners, mariadb, rabbitmq, memcached"
  echo "    openvswitch, libvirt, keystone, glance, placement"
  echo "    neutron, nova, cinder, horizon, barbican, btx"

}
install() {
  # check the group - osh-infra, osh, btx
  TAG_OPTS="--tags=openstack"
  KEY=""
  if [ x"${path_arr[$NAME]}" = x"$OSH_INFRA_PATH" ]; then
    TAG_OPTS="${TAG_OPTS},osh-infra --skip-tags=osh,btx"
    KEY="osh_infra_charts"
  elif [ x"${path_arr[$NAME]}" = x"$OSH_PATH" ]; then
    TAG_OPTS="${TAG_OPTS},osh --skip-tags=osh-infra,btx"
    KEY="osh_charts"
  elif [ x"${path_arr[$NAME]}" = x"$BTX_PATH" ]; then
    TAG_OPTS="${TAG_OPTS},btx --skip-tags=osh-infra,osh"
    KEY="btx_charts"
  else
    echo "Unknown name: $NAME"
    display_help
    exit 1
  fi
  source ~/.envs/burrito/bin/activate
  ansible-playbook --extra-vars=@vars.yml \
      --extra-vars="{\"$KEY\": [\"${NAME}\"]}" \
      $TAG_OPTS \
      ${KUBESPRAY_PATH}/burrito.yml
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
