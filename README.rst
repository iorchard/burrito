Burrito
=========

Burrito is the OpenStack on Kubernetes Platform.

Supported OS
---------------

* Rokcy Linux 8.x

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

   $ sudo dnf -y install git python3 python39 python3-cryptography

For other nodes::

   $ sudo dnf -y install python3 

Create and distribute ssh keypair.::

   $ ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
   $ ssh-copy-id <other_node>

Set up python virtual env
-----------------------------

Create python virtual env.::

   $ python3.9 -m venv ~/.envs/burrito

Activate the virtual env.::

   $ source ~/.envs/burrito/bin/activate

Get burrito source.

   $ git clone https://github.com/iorchard/burrito.git


Install Ceph
--------------

Go to burrito/ceph-ansible.::

   $ cd burrito/ceph-ansible

Install requirements.::

   $ python -m pip install -U pip
   $ python -m pip install wheel
   $ python -m pip install -r requirements.txt
   $ ansible-galaxy install -r requirements.yml

Create and edit inventory.::

   $ export MYSITE="mysite" # put your site name
   $ cp -a inventory/default inventory/$MYSITE
   $ vi inventory/$MYSITE/hosts
   bcontrol1 ansible_host=192.168.21.71 ansible_port=22 ansible_user=clex ansible_connection=local ansible_python_interpreter=/usr/bin/python3
   bcontrol2 ansible_host=192.168.21.72 ansible_port=22 ansible_user=clex
   bcontrol3 ansible_host=192.168.21.73 ansible_port=22 ansible_user=clex
   bcompute1 ansible_host=192.168.21.76 ansible_port=22 ansible_user=clex
   bcompute2 ansible_host=192.168.21.77 ansible_port=22 ansible_user=clex
   bstorage1 ansible_host=192.168.21.78 monitor_address=192.168.24.78 radosgw_address=192.168.24.78 ansible_port=22 ansible_user=clex
   bstorage2 ansible_host=192.168.21.79 monitor_address=192.168.24.79 radosgw_address=192.168.24.79 ansible_port=22 ansible_user=clex
   bstorage3 ansible_host=192.168.21.80 monitor_address=192.168.24.80 radosgw_address=192.168.24.80 ansible_port=22 ansible_user=clex
   
   [mons]
   bstorage[1:3]
   
   [mgrs]
   bstorage[1:3]
   
   [osds]
   bstorage[1:3]
   
   [rgws]
   bstorage[1:3]
   
   [clients]
   bcontrol[1:3]
   bcompute[1:2]

Network nodes are not included in the inventory since network nodes
do not use storage at all.

Create and update ansible.cfg.::

   $ sed "s/MYSITE/$MYSITE/" ansible.cfg.sample > ansible.cfg

Edit the global variables for your environment until "Do Not Edit Below" 
comment.::

   $ vi inventory/burrito/group_vars/all.yml
   ---
   # ceph network cidr - recommend the same cidr for public/cluster networks.
   public_network: 192.168.24.0/24
   cluster_network: "{{ public_network }}"
   
   # ceph osd volume device list
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd
   
   ###########################################
   # Do Not Edit Below!!!                    #
   ###########################################

* public_network: ceph public network cidr
* cluster_network: ceph cluster network cidr
* lvm_volumes: ceph osd devices

Check the connection to other nodes.::

   $ ansible -m ping all

Run the ceph-ansible playbook.::

   $ ansible-playbook site.yml

Run the burrito playbook.::

   $ ansible-playbook burrito.yml

Check ceph health status.::

   $ sudo ceph health
   HEALTH_OK


Install Kubernetes
---------------------

Go to burrito/kubespray.::

   $ cd burrito/kubespray

Install requirements.::

   $ python -m pip install -r requirements-2.12.txt

Create and edit inventory.::

   $ cp -a inventory/default inventory/burrito
   $ vi inventory/burrito/hosts
   burrito-ctrl1 ip=192.168.21.71 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
   burrito-ctrl2 ip=192.168.21.72
   burrito-ctrl3 ip=192.168.21.73
   burrito-net1 ip=192.168.21.74
   burrito-net2 ip=192.168.21.75
   burrito-comp1 ip=192.168.21.76
   burrito-comp2 ip=192.168.21.77
   burrito-ceph1 ip=192.168.21.78 radosgw_address=192.168.24.78
   burrito-ceph2 ip=192.168.21.79 radosgw_address=192.168.24.79
   
   # ceph rgw nodes
   [ceph_rgw]
   burrito-ceph[1:2]
   
   # kubernetes nodes
   [kube-master]
   burrito-ctrl[1:3]
   
   [kube-node]
   burrito-ctrl[1:3]
   burrito-net[1:2]
   burrito-comp[1:2]
   
   # openstack nodes
   [controller-node]
   burrito-ctrl[1:3]
   
   [network-node]
   burrito-net[1:2]
   
   [compute-node]
   burrito-comp[1:2]
   
   ###################################################
   ## Do not touch below if you are not an expert!!! #
   ###################################################

Create and update ansible.cfg.::

   $ sed "s/MYSITE/$MYSITE/" ansible.cfg.sample > ansible.cfg


Edit the variables for your environment until "Do Not Edit Below" comment.::

   $ vi vars.yml
   ---
   ### common
   common_password: '<password>'
   
   ### ceph-csi role variables
   ceph_monitors:
     - 192.168.24.78
     - 192.168.24.79
     - 192.168.24.80
   
   ### keepalived role variables
   keepalived_interface: "eth1"
   keepalived_vip: "192.168.21.90"
   keepalived_interface_svc: "eth0"
   keepalived_vip_svc: "192.168.20.90"
   
   # neutron
   neutron:
     tunnel: eth3
     tunnel_compute: eth3
     password: "{{ common_password }}"
   neutron_ml2_plugin: "ovs"
   ovs_dvr: true
   ovs_provider:
     - name: external
       bridge: br-ex
       iface: eth2
       vlan_ranges: ""
   bgp_dragent: true
   
   # nova
   nova:
     vncserver_proxyclient_interface: "eth1"
     hypervisor_host_interface: "eth1"
     libvirt_live_migration_interface: "eth1"
     password: "{{ common_password }}"
   
   # ceph_provisioners
   ceph_public_network: "192.168.24.0/24"
   ceph_cluster_network: "{{ ceph_public_network }}"
   
   ###################################################
   ## Do not touch below if you are not an expert!!! #
   ###################################################

* common_password: the password which is used by openstack compoenents
* keepalived_interface: management network interface name
* keepalived_vip: management virtual IP address
* keepalived_interface_svc: service network interface name
* keepalived_vip_svc: service virtual IP address
* neutron tunnel/tunnel_compute: overlay network interface name
* neutron ovs_provider iface: provider network interface name
* nova interfaces: management network interface name
* ceph_public_network: ceph public network cidr
* ceph cluster_network: ceph cluster network cidr

Check the connections.::

   $ ansible -m ping all

Run the kubespray playbook.::

   $ ansible-playbook -b --extra-vars=@vars.yml cluster.yml

Check kubernetes nodes.::

   $ sudo kubectl get nodes

Install helm-diff plugin.::

   $ sudo helm plugin install https://github.com/databus23/helm-diff

Run the burrito playbook.::

   $ ansible-playbook --extra-vars=@vars.yml burrito.yml

