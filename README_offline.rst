Burrito Offline Installation
================================

This is a guide to install Burrito in offline environment.

Use the Burrito CD or ISO to install in offline.

Supported OS
----------------

* Rocky Linux 8.x: Only supported OS currently

Assumptions
-------------

* OS is installed using Burrito CD/ISO.
* The first node in controller group is the ansible deployer.
* Ansible user in every node has a passwordless sudo privilege.
* All nodes should be in /etc/hosts.

Networks
-----------

I assume there are 5 networks.

* service network: Public service network (e.g. 192.168.20.0/24)
* management network: Management and internal network (e.g. 192.168.21.0/24)
* provider network: OpenStack provider network (e.g. 192.168.22.0/24)
* overlay network: OpenStack overlay network (e.g. 192.168.23.0/24)
* storage network: Ceph public/cluster network (e.g. 192.168.24.0/24)

Copy ssh keypair
-----------------

Create ssh key pair and distribute the public key to all other nodes.::

   $ ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''
   $ ssh-copy-id <other_node>

Set up the ISO repo
---------------------

Mount the iso file.

If you use the iso file,::

   $ sudo mount -o loop,ro <path/to/burrito_iso_file> /mnt

If you inserted the CD,::

    $ sudo mount -o ro /dev/sr0 /mnt

Install ansible in virtual env
----------------------------------

Untar burrito tarball from the mounted iso.::

   $ tar xvzf /mnt/burrito-<version>.tar.gz

Go to burrito directory.::

   $ cd burrito-<version>

Start offline repo and registry services.::

   $ ./scripts/offline_services.sh --up

Install python 3.9.::

   $ sudo dnf -y install python39

Create virtual env.::

   $ python3.9 -m venv ~/.envs/burrito

Activate the virtual env.::

   $ source ~/.envs/burrito/bin/activate

Install python packages.::

   $ pip install --no-index --find-links /mnt/pypi /mnt/pypi/{pip,wheel}-*
   $ pip install --no-index --find-links /mnt/pypi \
               --requirement requirements.txt

Prepare
--------

Run offline_prepare.sh script.::

   $ ./prepare_offline.sh

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
   ---
   ## common
   common_password: "<password>"
   # define network interface names
   svc_iface_name: eth0
   mgmt_iface_name: eth1
   provider_iface_name: eth2
   overlay_iface_name: eth3
   storage_iface_name: eth4

   ## ntp
   # Specify time servers for control nodes.
   # You can use the default ntp.org servers or time servers in your network.
   # If servers are offline and there is no time server in your network,
   #   set ntp_servers to empty list.
   #   Then, the control nodes will be the ntp peers.
   # ntp_servers: []
   ntp_servers:
     - 0.pool.ntp.org
     - 1.pool.ntp.org
     - 2.pool.ntp.org

   # ceph osd volume device list
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd

   ### keepalived VIP address
   keepalived_vip: "192.168.21.90"
  
   ### MTU setting
   calico_mtu: 1500
   openstack_mtu: 1500

   ### neutron
   # is_ovs: set true for openvswitch, set false for linuxbridge
   is_ovs: true
   bgp_dragent: false
   
   
   ###################################################
   ## Do not edit below if you are not an expert!!!  #
   ###################################################

Check the connection to other nodes.::

   $ ansible -m ping all

Install
----------

Run preflight playbook.::

   $ ./run.sh preflight

Check if yum repo is a local repo on all nodes.::

   $ sudo dnf repolist
   repo id                               repo name
   burrito                               Burrito Repo

Run HA stack playbook.::

   $ ./run.sh ha

Check if KeepAlived VIPs are created in the first controller node.

Run ceph playbook.::

   $ ./run.sh ceph

Check ceph health.::

   $ sudo ceph -s

Run k8s playbook.::

   $ ./run.sh k8s

Patch k8s.::

   $ ./run.sh patch

It will take some time to restart kube-apiserver after patch.

Check all pods are running and ready in kube-system namespace.::

   $ sudo kubectl get pods -n kube-system

Run registry playbook to pull, tag, and push images 
from the seed registry to the local registry.::

   $ ./run.sh registry

Check the images in the local registry.::

   $ curl -s <keepalived_vip>:32680/v2/_catalog

Repositories should not be empty.

Run burrito playbook.::

   $ ./run.sh burrito

Last but not least, Run landing playbook to set up local registry on k8s.::

   $ ./run.sh landing

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

