Burrito
=========

Burrito is the OpenStack on Kubernetes Platform.

Supported OS
---------------

* Rocky Linux 8.x

Assumptions
-------------

* The first node in controller group is the ansible deployer.
* Ansible user in every node has a sudo privilege.
* All nodes should be in /etc/hosts.

Networks
-----------

I assume there are 5 networks.

* service network: Public service network (e.g. 192.168.20.0/24)
* management network: Management and internal network (e.g. 192.168.21.0/24)
* provider network: OpenStack provider network (e.g. 192.168.22.0/24)
* overlay network: OpenStack overlay network (e.g. 192.168.23.0/24)
* storage network: Ceph public/cluster network (e.g. 192.168.24.0/24)

Install packages
-----------------

For deploy node::

   $ sudo dnf -y install git python3 python39 python3-cryptography epel-release

For other nodes::

   $ sudo dnf -y install python3 epel-release

Set up python virtual env
-----------------------------

Create python virtual env.::

   $ python3.9 -m venv ~/.envs/burrito

Activate the virtual env.::

   $ source ~/.envs/burrito/bin/activate

Get burrito source.

   $ git clone --recursive https://github.com/iorchard/burrito.git

Prepare
--------

Go to burrito.::

   $ cd burrito

Run prepare.sh script.::

   $ ./prepare.sh

Edit hosts.::

   $ vi hosts
   control1 ip=192.168.21.31 ansible_port=22 ansible_user=clex ansible_connection=local ansible_python_interpreter=/usr/bin/python3
   control2 ip=192.168.21.32 ansible_port=22 ansible_user=clex 
   control3 ip=192.168.21.33 ansible_port=22 ansible_user=clex
   network1 ip=192.168.21.34 ansible_port=22 ansible_user=clex
   network2 ip=192.168.21.35 ansible_port=22 ansible_user=clex
   compute1 ip=192.168.21.36 ansible_port=22 ansible_user=clex
   compute2 ip=192.168.21.37 ansible_port=22 ansible_user=clex
   storage1 ip=192.168.21.38 monitor_address=192.168.24.38 radosgw_address=192.168.24.38 ansible_port=22 ansible_user=clex
   storage2 ip=192.168.21.39 monitor_address=192.168.24.39 radosgw_address=192.168.24.39 ansible_port=22 ansible_user=clex
   storage3 ip=192.168.21.40 monitor_address=192.168.24.40 radosgw_address=192.168.24.40 ansible_port=22 ansible_user=clex
   
   # ceph nodes
   [mons]
   storage[1:3]
   
   [mgrs]
   storage[1:3]
   
   [osds]
   storage[1:3]
   
   [rgws]
   storage[1:3]
   
   [clients]
   control[1:3]
   compute[1:2]
   
   # kubernetes nodes
   [kube_control_plane]
   control[1:3]
   
   [kube_node]
   control[1:3]
   network[1:2]
   compute[1:2]
   
   # openstack nodes
   [controller-node]
   control[1:3]
   
   [network-node]
   network[1:2]
   
   [compute-node]
   compute[1:2]
   
   ###################################################
   ## Do not touch below if you are not an expert!!! #
   ###################################################

.. note:: If there is no network node, put control nodes in network-node group.

Edit vars.yml.::

   $ vi vars.yml
   ### common
   # deploy_ssh_key: (boolean) create ssh keypair and copy it to other nodes.
   # default: false
   deploy_ssh_key: true
   
   ### define network interface names
   # set overlay_iface_name to null if you do not want to set up overlay network.
   # then, only provider network will be set up.
   svc_iface_name: eth0
   mgmt_iface_name: eth1
   provider_iface_name: eth2
   overlay_iface_name: eth3
   storage_iface_name: eth4
   
   ### ntp
   # Specify time servers for control nodes.
   # You can use the default ntp.org servers or time servers in your network.
   # If servers are offline and there is no time server in your network,
   #   set ntp_servers to empty list.
   #   Then, the control nodes will be the ntp servers for other nodes.
   # ntp_servers: []
   ntp_servers:
     - 0.pool.ntp.org
     - 1.pool.ntp.org
     - 2.pool.ntp.org
   
   ### keepalived
   keepalived_vip: "192.168.21.90"
   
   ### storage
   # storage backends: ceph and(or) netapp
   # If there are multiple backends, the first one is the default backend.
   storage_backends:
     - netapp
     - ceph
   
   # ceph: set ceph configuration in group_vars/all/ceph_vars.yml
   # netapp: set netapp configuration in group_vars/all/netapp_vars.yml
   
   ### MTU setting
   calico_mtu: 1500
   openstack_mtu: 1500
   
   ### neutron
   # is_ovs: set false for linuxbridge(default), set true for openvswitch
   is_ovs: false
   bgp_dragent: false
   
   ###################################################
   ## Do not edit below if you are not an expert!!!  #
   ###################################################

If you set ceph in storage_backends, edit group_vars/all/ceph.yml.::

   ---
   # ceph config
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd
   ...

If you set netapp in storage_backends, edit group_vars/all/netapp.yml.::

   ---
   netapp:
     - name: netapp1
       managementLIF: "192.168.100.230"
       dataLIF: "192.168.140.19"
       svm: "svm01"
       username: "admin"
       password: "<netapp_admin_password>"
       nfsMountOptions: "nfsvers=4,lookupcache=pos"
       shares:
         - /dev03
   ...

Create a vault file to encrypt passwords.::

   $ ./vault.sh
   user password: 
   openstack admin password: 
   Encryption successful

Check the connection to other nodes.::

   $ ./run.sh ping

Install
----------

Run preflight playbook.::

   $ ./run.sh preflight

Run HA stack playbook.::

   $ ./run.sh ha

Check if KeepAlived VIPs are created in the first controller node.

Run ceph playbook if ceph is in storage_backends.::

   $ ./run.sh ceph

Check ceph health.::

   $ sudo ceph -s

Run k8s playbook.::

   $ ./run.sh k8s

Run netapp playbook if netapp is in storage_backends.::

   $ ./run.sh netapp

Check all pods are running and ready in trident namespace.::

   $ sudo kubectl get pods -n trident

Patch k8s.::

   $ ./run.sh patch

It will take some time to restart kube-apiserver after patch.
Check all pods are running in kube-system namespace.::

   $ sudo kubectl get pods -n kube-system

Run registry playbook to pull, tag, and push images
from seed registry to the local registry.::

   $ ./run.sh registry

Check the images in the local registry.::

   $ curl -s <keepalived_vip>:32680/v2/_catalog

Repositories should not be empty.

Run burrito playbook.::

   $ sudo helm plugin install https://github.com/databus23/helm-diff
   $ ./run.sh burrito

Check openstack status.::

   $ . ~/.btx.env
   $ bts
   root@btx-0:/# openstack volume service list
   root@btx-0:/# openstack network agent list
   root@btx-0:/# openstack compute service list

All services should be up and running.

Test
------

Source btx environment and run btx in test mode.::

   $ . ~/.btx.env

The command "btx --test"

* Creates a provider network and subnet.
  When it creates a provider network, it will ask an address pool range.
* Creates a cirros image.
* Adds security group rules.
* Creates a flavor.
* Creates an instance.
* Creates a volume.
* Attaches a volume to an instance.

If everything goes well, the output looks like this.::

   $ btx --test
   ...
   Creating provider network...
   Type the provider network address (e.g. 192.168.22.0/24): 192.168.22.0/24
   Okay. I got the provider network address: 192.168.22.0/24
   The first IP address to allocate (e.g. 192.168.22.100): 192.168.22.200
   The last IP address to allocate (e.g. 192.168.22.200): 192.168.22.210
   Okay. I got the last address of provider network pool: 192.168.22.210
   ...
   +------------------+------------------------------------------------+
   | Field            | Value                                          |
   +------------------+------------------------------------------------+
   | addresses        | private-net=192.168.22.207                     |
   | flavor           | m1.tiny (410f3140-3fb5-4efb-94e5-73d77d6242cf) |
   | image            | cirros (870cf94b-8d2b-43bd-b244-4bf7846ff39e)  |
   | name             | test                                           |
   | status           | ACTIVE                                         |
   | volumes_attached | id='2cf21340-b7d4-464f-a11b-22043cc2d3e6'      |
   +------------------+------------------------------------------------+

