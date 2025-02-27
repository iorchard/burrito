Burrito Scripts
===============

There are three scripts in this directory.

burrito.sh
-----------

This script is for installing/uninstalling each openstack component.

Usage::

   ./burrito.sh <action> <chart_name>
       <action>: install, uninstall
       <chart_name>
       ingress, ceph-provisioners, mariadb, rabbitmq, memcached
       openvswitch, libvirt, keystone, glance, placement
       neutron, nova, cinder, horizon, barbican, btx

For example, if we want to install glance, run it with install action.::

   $ ./burrito.sh install glance

If you want to uninstall glance, run it with uninstall action.::

   $ ./burrito.sh uninstall glance

clean_openstack.sh
-----------------------

This script is for deleting everything in openstack namespace.

Usage::

   $ ./clean_openstack.sh
   Enter machine Hostname : <Enter the hostname>


clean_k8s.sh
---------------

This script is for deleting kubernetes cluster.

Usage::

   $ ./clean_k8s.sh

