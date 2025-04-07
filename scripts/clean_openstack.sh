#!/bin/bash

function USAGE() {
  echo "USAGE: $0 [-h|-f]" 1>&2
  echo
  echo " -h --help   Display this help message."
  echo " -f --force  Force to delete all resources in openstack namespace."
  echo "             (default: Wait for deleting all resources)"
  echo
}

KUBECTL=$(type -p kubectl)
if [[ -z ${KUBECTL} ]]; then
  echo "Abort) kubectl command is not found."
  exit 1
fi
HELM=$(type -p helm)
if [[ -z ${HELM} ]]; then
  echo "Abort) helm command is not found."
  exit 1
fi

echo -n "Enter machine Hostname: "

read hn

if [ "${hn}" != "$HOSTNAME" ]
then
    echo "Hostname does not match!"
    exit 1
fi

OPT=$1
HELM_PARAM="--wait"
KUBECTL_PARAM="--wait"
if [[ "x--help" = "x${OPT}" ]] || [[ "x-h" = "x${OPT}" ]]; then
  USAGE
  exit 0
fi
if [[ "x--force" = "x${OPT}" ]] || [[ "x-f" = "x${OPT}" ]]; then
  HELM_PARAM=""
  KUBECTL_PARAM="--force --grace-period=0"
fi

# delete glance-storage-init job first
if sudo ${KUBECTL} get jobs glance-storage-init -n openstack &>/dev/null; then
  sudo ${KUBECTL} delete jobs glance-storage-init -n openstack ${KUBECTL_PARAM}
fi

for i in $(sudo ${HELM} list --all -q --namespace openstack)
do
  sudo ${HELM} uninstall $i ${HELM_PARAM} --no-hooks --namespace openstack
done

sudo ${KUBECTL} delete pvc --all -n openstack ${KUBECTL_PARAM}
sudo ${KUBECTL} delete configmap --all -n openstack ${KUBECTL_PARAM}
sudo ${KUBECTL} delete secret --all -n openstack ${KUBECTL_PARAM}
sudo ${KUBECTL} delete jobs --all -n openstack ${KUBECTL_PARAM}
sudo ${KUBECTL} delete pods --all -n openstack ${KUBECTL_PARAM}

# Kill qemu-system-x86_64 process
. ~/.envs/burrito/bin/activate && \
  ansible --background 30 --poll 5 --become compute-node \
    -a 'killall --wait qemu-system-x86_64'

# Unmount /var/lib/nova/instances on compute nodes
. ~/.envs/burrito/bin/activate && \
  ansible --become compute-node -m ansible.posix.mount \
    -a "path=/var/lib/nova/instances state=unmounted"

# Remove btx block in bashrc
. ~/.envs/burrito/bin/activate && \
  ansible kube_control_plane -m ansible.builtin.blockinfile \
    -a "path=/home/$USER/.bashrc marker='# {mark} BTX ENV BLOCK' state=absent"

