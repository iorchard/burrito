#!/bin/bash

echo -n "Enter machine Hostname: "

read hn

if [ "${hn}" != "$HOSTNAME" ]
then
    echo "Hostname does not match!"
    exit 1
fi

for i in $(sudo helm list --all -q --namespace openstack)
do
  sudo helm uninstall $i --no-hooks --namespace openstack
done

sudo kubectl delete pvc --all -n openstack --force --grace-period=0
sudo kubectl delete configmap --all -n openstack --force --grace-period=0
sudo kubectl delete secret --all -n openstack --force --grace-period=0
sudo kubectl delete jobs --all -n openstack --force --grace-period=0
sudo kubectl delete pods --all -n openstack --force --grace-period=0
