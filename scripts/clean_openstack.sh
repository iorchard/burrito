#!/bin/bash

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
function USAGE() {
  echo "USAGE: $0 [-h|-f]" 1>&2
  echo
  echo " -h --help   Display this help message."
  echo " -f --force  Force to delete all resources in openstack namespace."
  echo "             (default: Wait for deleting all resources)"
  echo
}
if [[ "x--help" = "x${OPT}" ]] || [[ "x-h" = "x${OPT}" ]]; then
  USAGE
  exit 0
fi
if [[ "x--force" = "x${OPT}" ]] || [[ "x-f" = "x${OPT}" ]]; then
  HELM_PARAM=""
  KUBECTL_PARAM="--force --grace-period=0"
fi

# delete glance-storage-init job first
sudo kubectl delete jobs glance-storage-init -n openstack ${KUBECTL_PARAM}

for i in $(sudo helm list --all -q --namespace openstack)
do
  sudo helm uninstall $i ${HELM_PARAM} --no-hooks --namespace openstack
done

sudo kubectl delete pvc --all -n openstack ${KUBECTL_PARAM}
sudo kubectl delete configmap --all -n openstack ${KUBECTL_PARAM}
sudo kubectl delete secret --all -n openstack ${KUBECTL_PARAM}
sudo kubectl delete jobs --all -n openstack ${KUBECTL_PARAM}
sudo kubectl delete pods --all -n openstack ${KUBECTL_PARAM}

# Remove btx block in bashrc
source ~/.envs/burrito/bin/activate && \
  ansible kube_control_plane -m ansible.builtin.blockinfile \
    -a "path=/home/$USER/.bashrc marker='# {mark} BTX ENV BLOCK' state=absent"

