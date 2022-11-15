#!/bin/bash

echo -n "Enter machine Hostname : "

read a

if [ "${a}" != "$(hostname)" ]
then
    echo "Hostname do not match!"
    exit 1
fi

CHARTS=$(helm list --all -q --namespace openstack)
for i in $(helm list --all -q --namespace openstack)
do
  helm uninstall $i --no-hooks --namespace openstack
done

kubectl delete pvc --all -n openstack --force --grace-period=0
kubectl delete configmap --all -n openstack --force --grace-period=0
kubectl delete secret --all -n openstack --force --grace-period=0
kubectl delete jobs --all -n openstack --force --grace-period=0
kubectl delete pods --all -n openstack --force --grace-period=0

