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

Run prepare.sh script with offline flag.::

   $ ./prepare.sh offline

Edit hosts.::

   $ vi hosts
   control1 ip=192.168.21.31 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
   control2 ip=192.168.21.32
   control3 ip=192.168.21.33
   network1 ip=192.168.21.34
   network2 ip=192.168.21.35
   compute1 ip=192.168.21.36
   compute2 ip=192.168.21.37
   storage1 ip=192.168.21.38 monitor_address=192.168.24.38 radosgw_address=192.168.24.38
   storage2 ip=192.168.21.39 monitor_address=192.168.24.39 radosgw_address=192.168.24.39
   storage3 ip=192.168.21.40 monitor_address=192.168.24.40 radosgw_address=192.168.24.40
 
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
   
   # metallb
   # To use metallb LoadBalancer, set this to true
   metallb_enabled: false
   # set up MetalLB LoadBalancer IP range or cidr notation
   # IP range: 192.168.20.95-192.168.20.98 (4 IPs can be assigned)
   # Only one IP: 192.168.20.95/32
   metallb_ip_range:
     - "192.168.20.95-192.168.20.98"
   
   ###################################################
   ## Do not edit below if you are not an expert!!!  #
   ###################################################

If ceph is in storage_backends, edit group_vars/all/ceph_vars.yml.::

   ---
   # ceph config
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd
   ...

If netapp is in storage_backends, edit group_vars/all/netapp_vars.yml.::

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

Check if yum repo is a local repo on all nodes.::

   $ sudo dnf repolist
   repo id                               repo name
   burrito                               Burrito Repo

Run HA stack playbook.::

   $ ./run.sh ha

Check if KeepAlived VIP is created in management interface 
on the first controller node.

Run ceph playbook if ceph is in storage_backends.::

   $ ./run.sh ceph

Check ceph health after running ceph playbook.::

   $ sudo ceph -s

Run k8s playbook.::

   $ ./run.sh k8s

Run netapp playbook if netapp is in storage_backends.::

   $ ./run.sh netapp

Check all pods are running and ready in trident namespace after running
netapp playbook.::

   $ sudo kubectl get pods -n trident

Patch k8s.::

   $ ./run.sh patch

It will take some time to restart kube-apiserver after patch.
Check all pods are running and ready in kube-system namespace.::

   $ sudo kubectl get pods -n kube-system

Run registry playbook to pull, tag, and push images to the local registry.::

   $ ./run.sh registry

Check the images in the local registry.::

   $ curl -s <keepalived_vip>:32680/v2/_catalog

Repositories should not be empty.

Run burrito playbook.::

   $ ./run.sh burrito

Last but not least, 
Run landing playbook to set up genesis registry and local repository on k8s.::

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
   +------------------+------------------------------------------------------------------------------------+
   | Field            | Value                                                                              |
   +------------------+------------------------------------------------------------------------------------+
   | addresses        | private-net=172.30.1.45, 192.168.22.113                                            |
   | flavor           | disk='1', ephemeral='0', , original_name='m1.tiny', ram='512', swap='0', vcpus='1' |
   | image            | cirros (69794a94-ef91-4057-b64c-13ec53a8015f)                                      |
   | name             | test                                                                               |
   | status           | ACTIVE                                                                             |
   | volumes_attached | delete_on_termination='False', id='afe28a3b-18f1-4230-b499-f707d73b1d43'           |
   +------------------+------------------------------------------------------------------------------------+

