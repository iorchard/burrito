Burrito
=========

Burrito is the OpenStack on Kubernetes Platform.

Supported OS
---------------

* Rocky Linux 8.x

Assumptions
-------------

* The first node in controller group is the ansible deployer.
* Ansible user in every node has a passwordless sudo privilege.

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

Create ssh key pair and distribute the public key to all other nodes.::

   $ ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
   $ ssh-copy-id <other_node>

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
   control1 ansible_host=192.168.21.31 ansible_port=22 ansible_user=clex ansible_connection=local ansible_python_interpreter=/usr/bin/python3
   control2 ansible_host=192.168.21.32 ansible_port=22 ansible_user=clex 
   control3 ansible_host=192.168.21.33 ansible_port=22 ansible_user=clex
   network1 ansible_host=192.168.21.34 ansible_port=22 ansible_user=clex
   network2 ansible_host=192.168.21.35 ansible_port=22 ansible_user=clex
   compute1 ansible_host=192.168.21.36 ansible_port=22 ansible_user=clex
   compute2 ansible_host=192.168.21.37 ansible_port=22 ansible_user=clex
   storage1 ansible_host=192.168.21.38 monitor_address=192.168.24.38 radosgw_address=192.168.24.38 ansible_port=22 ansible_user=clex
   storage2 ansible_host=192.168.21.39 monitor_address=192.168.24.39 radosgw_address=192.168.24.39 ansible_port=22 ansible_user=clex
   storage3 ansible_host=192.168.21.40 monitor_address=192.168.24.40 radosgw_address=192.168.24.40 ansible_port=22 ansible_user=clex
   
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
   controller[1:3]
   compute[1:2]
   
   # kubernetes nodes
   [kube-master]
   controller[1:3]
   
   [kube-node]
   controller[1:3]
   network[1:2]
   compute[1:2]
   
   # openstack nodes
   [controller-node]
   controller[1:3]
   
   [network-node]
   network[1:2]
   
   [compute-node]
   compute[1:2]
   
   ###################################################
   ## Do not touch below if you are not an expert!!! #
   ###################################################

Edit vars.yml.::

   $ vi vars.yml
   ---
   ## common
   common_password: '<password>'
   # define network interface names
   svc_iface_name: eth0
   mgmt_iface_name: eth1
   provider_iface_name: eth2
   overlay_iface_name: eth3
   
   ## ceph-ansible                     #
   # ceph network cidr - recommend the same cidr for public/cluster networks.
   public_network: 192.168.24.0/24
   cluster_network: "{{ public_network }}"
   
   # ceph osd volume device list
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd
   
   ## kubespray                        #
   # default pod replicas == # of controllers
   pod:
     replicas: "{{ groups['controller-node']|length }}"
   
   ### keepalived role variables
   keepalived_interface: "{{ mgmt_iface_name }}"
   keepalived_vip: "192.168.21.90"
   keepalived_interface_svc: "{{ svc_iface_name }}"
   keepalived_vip_svc: "192.168.20.90"
   
   ###################################################
   ## Do not edit below if you are not an expert!!!  #
   ###################################################

Check the connection to other nodes.::

   $ ansible -m ping all

Install
----------

Install ceph.::

   $ ansible-playbook --extra-vars=@vars.yml ceph.yml

Check ceph health.::

   $ sudo ceph -s

Install HA stack.::

   $ ansible-playbook --extra-vars=@vars.yml kubespray/ha.yml

Install k8s.::

   $ ansible-playbook --extra-vars=@vars.yml -b k8s.yml

Patch k8s.::

   $ ansible-playbook --extra-vars=@vars.yml patch.yml

It will take some time to restart kube-apiserver after patch.

Check all pods are running in kube-system namespace.::

   $ sudo kubectl get pods -n kube-system

Run image_push.yml playbook to pull, tag, and push openstack images to 
the local registry.::

   $ ansible-playbook --extra-vars=@vars.yml image_push.yml

Check the images in the local registry.::

   $ curl -s <keepalived_vip>:32680/v2/_catalog

Repositories should not be empty.

Install burrito.::

   $ sudo helm plugin install https://github.com/databus23/helm-diff
   $ ansible-playbook --extra-vars=@vars.yml burrito.yml

Check openstack status.::

   $ . ~/.btx.env
   $ bts
   btx@btx-0:/$ openstack volume service list
   btx@btx-0:/$ openstack network agent list
   btx@btx-0:/$ openstack compute service list

All services should be up and running.

Test
------

Source btx environment and run btx in test mode.::

   $ . ~/.btx.env

The command "btx --test"

* Creates a private/provider network and subnet
  When it creates provider network, it will ask address pool range.
* Creates a router
* Creates a cirros image
* Adds security group rules
* Creates a flavor
* Creates an instance
* Adds a floating ip to an instance
* Creates a volume
* Attaches a volume to an instance

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
   | addresses        | private-net=172.30.1.30, 192.168.22.195        |
   | flavor           | m1.tiny (410f3140-3fb5-4efb-94e5-73d77d6242cf) |
   | image            | cirros (870cf94b-8d2b-43bd-b244-4bf7846ff39e)  |
   | name             | test                                           |
   | status           | ACTIVE                                         |
   | volumes_attached | id='2cf21340-b7d4-464f-a11b-22043cc2d3e6'      |
   +------------------+------------------------------------------------+

