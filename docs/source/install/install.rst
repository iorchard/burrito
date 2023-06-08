Burrito Installation
====================

This is a guide to install Burrito in online environment.

Supported OS
-------------

* Rocky Linux 8.x

Networks
-----------

The standard number of networks for burrito is 5.

* service network: Public service network (e.g. 192.168.20.0/24)
* management network: Management and internal network (e.g. 192.168.21.0/24)
* provider network: OpenStack provider network (e.g. 192.168.22.0/24)
* overlay network: OpenStack overlay network (e.g. 192.168.23.0/24)
* storage network: Ceph public/cluster network (e.g. 192.168.24.0/24)

If you do not know what each network is for, consult openstack experts.

Reference network architecture
++++++++++++++++++++++++++++++

This is the reference network architecture.

* control/compute machines have all 5 networks.
* No ip addresses are assigned on the provider network.
* storage machines have 2 networks (management and storage)

========  ============ ============ ============ ============ ============
hostname  service      management   provider     overlay      storage
--------  ------------ ------------ ------------ ------------ ------------
 .        eth0         eth1         eth2         eth3         eth4
 .        192.168.20.x 192.168.21.x 192.168.22.x 192.168.23.x 192.168.24.x 
========  ============ ============ ============ ============ ============
control1  .101          .101          (no ip)     .101           .101
control2  .102          .102          (no ip)     .102           .102
control3  .103          .103          (no ip)     .103           .103
compute1  .104          .104          (no ip)     .104           .104
compute2  .105          .105          (no ip)     .105           .105
storage1                .106                                     .106
storage2                .107                                     .107
storage3                .108                                     .108
========  ============ ============ ============ ============ ============

* KeepAlived VIP on management: 192.168.21.100
* KeepAlived VIP on service: 192.168.20.100

Pre-requisites
---------------

* Rocky Linux 8.x is installed on every node.
* The python3 package should be already installed on every node.
* The first node in control group is the ansible deployer.
* Ansible user in every node has a sudo privilege.
* All nodes should be in /etc/hosts on the deployer node.

Here is the example of /etc/hosts on the deployer node.::

   127.0.0.1 localhost
   192.168.21.101 control1
   192.168.21.102 control2 
   192.168.21.103 control3 
   192.168.21.104 compute1 
   192.168.21.105 compute2 
   192.168.21.106 storage1 
   192.168.21.107 storage2 
   192.168.21.108 storage3 

Prepare
--------

Install git package on the deployer if not already installed.::

   $ sudo dnf -y install git

Get the burrito source.::

   $ git clone --recursive https://github.com/iorchard/burrito.git

Go to burrito directory.::

   $ cd burrito

Run prepare.sh script with offline flag.::

   $ ./prepare.sh
   Enter management network interface name: eth1

It will prompt for the management network interface name. 
Enter the management network interface name. (e.g. eth1)

inventory hosts and variables
+++++++++++++++++++++++++++++

There are 4 groups of hosts in burrito.

* Control node: runs kubernetes and openstack control-plane components.
* Network node: runs kubernetes worker and openstack network services.
* Compute node: runs kubernetes worker and openstack hypervisor and network
  agent to operate instances.
* Storage node: runs Ceph storage services - monitor, manager, osd, 
  rados gateway.

Network node is optional.
Control node usually acts as both control node and network node.

Edit hosts inventory file.::

   $ vi hosts
   control1 ip=192.168.21.101 ansible_connection=local ansible_python_interpreter=/usr/bin/python3
   control2 ip=192.168.21.102
   control3 ip=192.168.21.103
   compute1 ip=192.168.21.104
   compute2 ip=192.168.21.105
   storage1 ip=192.168.21.106 monitor_address=192.168.24.106 radosgw_address=192.168.24.106
   storage2 ip=192.168.21.107 monitor_address=192.168.24.107 radosgw_address=192.168.24.107
   storage3 ip=192.168.21.108 monitor_address=192.168.24.108 radosgw_address=192.168.24.108
   
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
   compute[1:2]
   
   # openstack nodes
   [controller-node]
   control[1:3]
   
   [network-node]
   control[1:3]
   
   [compute-node]
   compute[1:2]
   
   ###################################################
   ## Do not touch below if you are not an expert!!! #
   ###################################################

Beware that control nodes are in network-node group since there is no
network node in this case.

Edit vars.yml.::

   $ vi vars.yml
   ---
   ### common
   # deploy_ssh_key: (boolean) create ssh keypair and copy it to other nodes.
   # default: false
   deploy_ssh_key: false
   
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
   
   ### keepalived VIP on management network (mandatory)
   keepalived_vip: ""
   # keepalived VIP on service network (optional)
   # Set this if you do not have a direct access to management network
   # so you need to access horizon dashboard through service network.
   keepalived_vip_svc: ""
   
   ### metallb
   # To use metallb LoadBalancer, set this to true
   metallb_enabled: false
   # set up MetalLB LoadBalancer IP range or cidr notation
   # IP range: 192.168.20.95-192.168.20.98 (4 IPs can be assigned.)
   # CIDR: 192.168.20.128/26 (192.168.20.128 - 191 can be assigned.)
   # Only one IP: 192.168.20.95/32
   metallb_ip_range:
     - "192.168.20.95-192.168.20.98"
    
   ### storage
   # storage backends: ceph and(or) netapp
   # If there are multiple backends, the first one is the default backend.
   storage_backends:
     - netapp
     - ceph
   
   # ceph: set ceph configuration in group_vars/all/ceph_vars.yml
   # netapp: set netapp configuration in group_vars/all/netapp_vars.yml
   
   ###################################################
   ## Do not edit below if you are not an expert!!!  #
   ###################################################

Description of each variable
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

deploy_ssh_key (default: false)
  If true, it creates a ssh keypair on the deployer node and copy the public
  key to other nodes. Ansible will use the public key to ssh into other nodes
  after deploying the public key.

  If false, it does not create a ssh keypair. Ansible will use vault-encrypted
  user's password to ssh into other nodes.

\*_iface_name
  Set each network interface name.

  If you want to set up only provider network, set overlay_iface_name to null.
  Then, openstack neutron will disable self-service(overlay) network.

ntp_servers (default: {0,1,2}.pool.ntp.org)
  Specify time servers for control nodes.
  You can use the default ntp.org server or time servers in your network.

  If servers are offline and there is no time server in your network,
  set ntp_servers to empty list(ntp_servers: []). Then the control nodes
  will be the ntp servers for other nodes.

keepalived_vip (mandatory)
  Assign VIP address on management network for LoadBalancing and 
  High Availability to internal services. This is mandatory.

keepalived_vip_svc (optional)
  Assign VIP address on service network for horizon dashboard service.
  Set this if you do not have a direct access to management network.

  If it is not assigned, you have to connect to horizon dashboard via
  keepalived_vip on management network.

metallb_enabled (default: false)
  Set true to use metallb LoadBalancer.
  (See ` what is metallb? <https://metallb.universe.tf/>`_)

metallb_ip_range
  Set metallb LoadBalancer IP range or cidr notation.

  * IP range: 192.168.20.95-192.168.20.98 (4 IPs can be assigned.)
  * CIDR: 192.168.20.128/26 (192.168.20.128 - 191 can be assigned.)
  * Only one IP: 192.168.20.95/32 (192.168.20.95 can be assigned.)

storage_backends
  Burrito supports two storage backends - ceph and/or netapp.

  If there are multiple backends, the first one is the default backend.
  It means the default storageclass, glance store and the default cinder 
  volume type is the first backend.

  The Persistent Volumes are created on the default backend if you do not 
  specify the storageclass name.
  The volumes are created on the default volume type if you do not specify
  the volume type.

storage variables
+++++++++++++++++

If ceph is in storage_backends, 
run lsblk command on storage nodes to get the device names.::

   storage1$ lsblk -p
   NAME        MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
   /dev/sda      8:0    0  50G  0 disk 
   └─/dev/sda1   8:1    0  50G  0 part /
   /dev/sdb      8:16   0  50G  0 disk 
   /dev/sdc      8:32   0  50G  0 disk 
   /dev/sdd      8:48   0  50G  0 disk 

In this case, /dev/sda is the OS disk and /dev/sd{b,c,d} are for ceph
OSD disks.

Edit group_vars/all/ceph_vars.yml and add /dev/sd{b,c,d} in it.::

   $ vi group_vars/all/ceph_vars.yml
   ---
   # ceph config
   lvm_volumes:
     - data: /dev/sdb
     - data: /dev/sdc
     - data: /dev/sdd
   ...

If netapp is in storage_backends, edit group_vars/all/netapp_vars.yml.::

   $ vi group_vars/all/netapp_vars.yml
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


If you do not know what these netapp variables are, consult netapp engineer.

Create a vault file to encrypt passwords.::

   $ ./run.sh vault
   <user> password:
   openstack admin password:
   Encryption successful

Enter <user> password for ssh connection to other nodes.

Enter openstack admin password which will be used when you connect to 
openstack horizon dashboard.

Check the connections to other nodes.::

   $ ./run.sh ping

It should show SUCCESS on all nodes.

Install
--------

There should be no *failed* tasks in *PLAY RECAP* on each playbook run.

For example::

   PLAY RECAP *****************************************************************
   control1                   : ok=20   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
   control2                   : ok=19   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
   control3                   : ok=19   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

Each step has a verification process, so be sure to verify 
before proceeding to the next step. 

**Never proceed to the next step if the verification fails.**

Step.1 Preflight
+++++++++++++++++

The Preflight installation step implements the following tasks.

* Set up a local yum repository.
* Configure NTP time servers and clients.
* Deploy the public ssh key to other nodes (if deploy_ssh_key is true).

Install
^^^^^^^

Run preflight playbook.::

   $ ./run.sh preflight

Verify
^^^^^^

Check if the ntp servers and clients are configured.

When you set ntp_servers to the default ntp servers,
each control node should have the ntp pool servers on the internet.::

   control1$ chronyc sources
   MS Name/IP address         Stratum Poll Reach LastRx Last sample      
   =========================================================================
   ^* send.mx.cdnetworks.com  2  10   377    98  -1096us[-1049us] +/-   49ms
   ^- 121.162.54.1            3   6   377     1  -4196us[-4196us] +/-   38ms
   ^+ 106.247.248.106         2  10   377    50  +2862us[+2862us] +/-   61ms

Compute/storage nodes should have control nodes as time servers.::

   $ chronyc sources
   MS Name/IP address      Stratum Poll Reach LastRx Last sample               
   ========================================================================
   ^* control1             8   6   377    46    -15us[  -44us] +/-  212us
   ^- control2             9   6   377    47    -57us[  -86us] +/-  513us
   ^- control3             9   6   377    47    -97us[ -126us] +/-  674us

Step.2 HA 
++++++++++

The HA installation step implements the following tasks.

* Set up KeepAlived service.
* Set up HAProxy service.

KeepAlived and HAProxy services are the vital services for burrito platform.

OpenStack ingress, local container registry, local yum repository,
ceph Rados Gateway services are dependent of them.

Install
^^^^^^^

Run HA stack playbook.::

   $ ./run.sh ha

Verify
^^^^^^

Check if keepalived and haproxy are running on control nodes.::

   $ sudo systemctl status keepalived haproxy
   keepalived.service - LVS and VRRP High Availability Monitor
   ...
      Active: active (running) since Wed 2023-05-31 17:29:05 KST; 6min ago
   ...
   haproxy.service - HAProxy Load Balancer
   ...
      Active: active (running) since Wed 2023-05-31 17:28:52 KST; 8min ago

Check if keepalived_vip is created on the management interface 
in the first control node.::

   $ ip -br -4 address show dev eth1
   eth1             UP             192.168.21.101/24 192.168.21.100/32 

Check if keepalived_vip_svc is created on the service interface 
in the first control node if you set it up.::

   $ ip -br -4 address show dev eth0
   eth0             UP             192.168.20.101/24 192.168.20.100/32 

Step.3 Ceph
+++++++++++

Skip this step if ceph is **not** in storage_backends.

The Ceph installation step implements the following tasks.

* Install ceph server and client packages in storage nodes.
* Install ceph client packages in other nodes.
* Set up ceph monitor, manager, osd, rados gateway services on storage nodes.

Install
^^^^^^^

Run ceph playbook if ceph is in storage_backends.::

   $ ./run.sh ceph

Verify
^^^^^^

Check ceph health after running ceph playbook.::

   $ sudo ceph health
   HEALTH_OK

It should show HEALTH_OK.

To get the detailed health status, run `sudo ceph -s` command.
It will show the output like this.::

   $ sudo ceph -s
     cluster:
       id:     cd7bdd5a-1814-4e6a-9e07-c2bdc3f53fea
       health: HEALTH_OK
    
     services:
       mon: 3 daemons, quorum storage1,storage2,storage3 (age 17h)
       mgr: storage2(active, since 17h), standbys: storage1, storage3
       osd: 9 osds: 9 up (since 17h), 9 in (since 17h)
       rgw: 3 daemons active (3 hosts, 1 zones)
    
     data:
       pools:   10 pools, 513 pgs
       objects: 2.54k objects, 7.3 GiB
       usage:   19 GiB used, 431 GiB / 450 GiB avail
       pgs:     513 active+clean

There are 4 services - mon, mgr, osd, and rgw.

Sometimes it could show `HEALTH_WARN <something> have recently crashed`.
Don't worry. it is mostly harmless warning.

List the crashes.::

   $ sudo ceph crash ls

Archive all crashes.::

   $ sudo ceph crash archive-all

Then, check ceph health again. It should show HEALTH_OK now.

Step.4 Kubernetes
+++++++++++++++++

The Kubernetes installation step implements the following tasks.

* Install kubernetes binaries in kubernetes nodes.
* Set up kubernetes control plane.
* Set up kubernete worker nodes.
* Set up the local registry in kube-system namespace.

Install
^^^^^^^

Run k8s playbook.::

   $ ./run.sh k8s

Verify
^^^^^^

Check all nodes are in ready state.::

   $ sudo kubectl get nodes
   NAME       STATUS   ROLES           AGE   VERSION
   compute1   Ready    <none>          15m   v1.24.14
   compute2   Ready    <none>          15m   v1.24.14
   control1   Ready    control-plane   17m   v1.24.14
   control2   Ready    control-plane   16m   v1.24.14
   control3   Ready    control-plane   16m   v1.24.14


Step.5 Netapp
+++++++++++++

Skip this step if netapp is **not** in storage_backends.

The Netapp installation step implements the following tasks.

* Install trident components in trident namespace.
* Set up a netapp backend.
* Create a netapp storageclass.

Install
^^^^^^^

Run netapp playbook.::

   $ ./run.sh netapp

Verify
^^^^^^

Check all pods are running and ready in trident namespace.::

   $ sudo kubectl get pods -n trident
   NAME                           READY   STATUS    RESTARTS   AGE
   trident-csi-6b96bb4f87-tw22r   6/6     Running   0          43s
   trident-csi-84g2x              2/2     Running   0          42s
   trident-csi-f6m8w              2/2     Running   0          42s
   trident-csi-klj7h              2/2     Running   0          42s
   trident-csi-kv9mw              2/2     Running   0          42s
   trident-csi-r8gqv              2/2     Running   0          43s

Step.6 Patch
+++++++++++++

The Patch installation step implements the following tasks.

* Install ceph-csi driver if ceph is in storage_backends.
* Patch containerd configuration.
* Patch kube-apiserver.

Install
^^^^^^^

Run patch playbook.::

   $ ./run.sh patch

Verify
^^^^^^

It will take some time to restart kube-apiserver after patch.

Check all pods are running and ready in kube-system namespace.::

   $ sudo kubectl get pods -n kube-system
   NAME                                       READY STATUS    RESTARTS      AGE
   calico-kube-controllers-67c66cdbfb-rz8lz   1/1   Running   0             60m
   calico-node-28k2c                          1/1   Running   0             60m
   calico-node-7cj6z                          1/1   Running   0             60m
   calico-node-99s5j                          1/1   Running   0             60m
   calico-node-tnmht                          1/1   Running   0             60m
   calico-node-zmpxs                          1/1   Running   0             60m
   coredns-748d85fb6d-c8cj2                   1/1   Running   1 (28s ago)   59m
   coredns-748d85fb6d-gfv98                   1/1   Running   1 (27s ago)   59m
   dns-autoscaler-795478c785-hrjqr            1/1   Running   1 (32s ago)   59m
   kube-apiserver-control1                    1/1   Running   0             33s
   kube-apiserver-control2                    1/1   Running   0             34s
   kube-apiserver-control3                    1/1   Running   0             35s
   kube-controller-manager-control1           1/1   Running   1             62m
   kube-controller-manager-control2           1/1   Running   1             62m
   kube-controller-manager-control3           1/1   Running   1             62m
   kube-proxy-jjq5l                           1/1   Running   0             61m
   kube-proxy-k4kxq                           1/1   Running   0             61m
   kube-proxy-lqtgc                           1/1   Running   0             61m
   kube-proxy-qhdzh                           1/1   Running   0             61m
   kube-proxy-vxrg8                           1/1   Running   0             61m
   kube-scheduler-control1                    1/1   Running   2             62m
   kube-scheduler-control2                    1/1   Running   1             62m
   kube-scheduler-control3                    1/1   Running   1             62m
   nginx-proxy-compute1                       1/1   Running   0             60m
   nginx-proxy-compute2                       1/1   Running   0             60m
   nodelocaldns-5dbbw                         1/1   Running   0             59m
   nodelocaldns-cq2sd                         1/1   Running   0             59m
   nodelocaldns-dzcjr                         1/1   Running   0             59m
   nodelocaldns-plhwm                         1/1   Running   0             59m
   nodelocaldns-vlb8w                         1/1   Running   0             59m


Step.7 Burrito
+++++++++++++++

The Burrito installation step implements the following tasks.

* Create a rados gateway user(default: cloudpc) and 
  a client configuration(s3cfg).
* Deploy nova vnc TLS certificate.
* Deploy openstack components.
* Create a nova ssh keypair and copy them on every compute nodes.

Install
^^^^^^^

Run burrito playbook.::

   $ sudo helm plugin install https://github.com/databus23/helm-diff
   $ ./run.sh burrito

Verify
^^^^^^

Check all pods are running and ready in openstack namespace.::

   $ sudo kubectl get pods -n openstack
   NAME                                   READY   STATUS      RESTARTS   AGE
   barbican-api-664986fd5-jkp9x           1/1     Running     0          4m23s
   ...
   rabbitmq-rabbitmq-0                    1/1     Running     0          27m
   rabbitmq-rabbitmq-1                    1/1     Running     0          27m
   rabbitmq-rabbitmq-2                    1/1     Running     0          27m


Congratulations! 

You've just finished the installation of burrito platform.

Horizon
----------

The horizon dashboard listens on tcp 31000 on control nodes.

Here is how to connect to horizon dashboard on your browser.

#. Open your browser.

#. If keepalived_vip_svc is set,
   go to https://<keepalived_vip_svc>:31000/

#. If keepalived_vip_svc is not set,
   go to https://<keepalived_vip>:31000/

#. Accept the self-signed TLS certificate and log in.
   The admin password is the one you set when you run vault.sh script
   (openstack admin password:).

Next, perform the basic openstack operation test using btx (burrito toolbox).

BTX
---

BTX is a toolbox for burrito platform.
It should be already up and running.::

   $ sudo kubectl -n openstack get pods -l application=btx
   NAME    READY   STATUS    RESTARTS   AGE
   btx-0   1/1     Running   0          36m

Let's go into btx shell (bts).::

   $ . ~/.btx.env
   $ bts

Check openstack volume service status.::

   root@btx-0:/# openstack volume service list
   +------------------+------------------------------+------+---------+-------+----------------------------+
   | Binary           | Host                         | Zone | Status  | State | Updated At                 |
   +------------------+------------------------------+------+---------+-------+----------------------------+
   | cinder-scheduler | cinder-volume-worker         | nova | enabled | up    | 2023-05-31T12:05:02.000000 |
   | cinder-volume    | cinder-volume-worker@rbd1    | nova | enabled | up    | 2023-05-31T12:05:02.000000 |
   | cinder-volume    | cinder-volume-worker@netapp1 | nova | enabled | up    | 2023-05-31T12:05:07.000000 |
   +------------------+------------------------------+------+---------+-------+----------------------------+

* All services should be `enabled` and `up`.
* If you set up both ceph and netapp storage backends, 
  both volume services are enabled and up in the output.
* The cinder-volume-worker@rbd1 is the service for ceph backend
  and the cinder-volume-worker@netapp1 is the service for netapp backend.

Check openstack network agent status.::

   root@btx-0:/# openstack network agent list
   +--------------------------------------+--------------------+----------+-------------------+-------+-------+---------------------------+
   | ID                                   | Agent Type         | Host     | Availability Zone | Alive | State | Binary                    |
   +--------------------------------------+--------------------+----------+-------------------+-------+-------+---------------------------+
   | 0b4ddf14-d593-44bb-a0aa-2776dfc20dc9 | Metadata agent     | control1 | None              | :-)   | UP    | neutron-metadata-agent    |
   | 189c6f4a-4fad-4962-8439-0daf400fcae0 | DHCP agent         | control3 | nova              | :-)   | UP    | neutron-dhcp-agent        |
   | 22b0d873-4192-41ad-831b-0d468fa2e411 | Metadata agent     | control3 | None              | :-)   | UP    | neutron-metadata-agent    |
   | 4e51b0a0-e38a-402e-bbbd-5b759130220f | Linux bridge agent | compute1 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | 56e43554-47bc-45c8-8c46-fb2aa0557cc0 | DHCP agent         | control1 | nova              | :-)   | UP    | neutron-dhcp-agent        |
   | 7f51c2b7-b9e3-4218-9c7b-94076d2b162a | Linux bridge agent | compute2 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | 95d09bfd-0d71-40d4-a5c2-d46eb640e967 | DHCP agent         | control2 | nova              | :-)   | UP    | neutron-dhcp-agent        |
   | b76707f2-f13c-4f68-b769-fab8043621c7 | Linux bridge agent | control3 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | c3a6a32c-cbb5-406c-9b2f-de3734234c46 | Linux bridge agent | control1 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | c7187dc2-eea3-4fb6-a3f6-1919b82ced5b | Linux bridge agent | control2 | None              | :-)   | UP    | neutron-linuxbridge-agent |
   | f0a396d3-8200-41c3-9057-5d609204be3f | Metadata agent     | control2 | None              | :-)   | UP    | neutron-metadata-agent    |
   +--------------------------------------+--------------------+----------+-------------------+-------+-------+---------------------------+

* All agents should be :-) and UP.
* If you set overlay_iface_name to null, there is no 'L3 agent' in Agent Type
  column.
* If you set is_ovs to false, there should be 'Linux bridge agent' in Agent
  Type column.
* If you set is_ovs to true, there should be 'Open vSwitch agent' in Agent
  Type column.


Check openstack compute service status.::

   root@btx-0:/# openstack compute service list
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   | ID                                   | Binary         | Host                            | Zone     | Status  | State | Updated At                 |
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   | b31c814b-d210-4e52-9d6e-59090f8a641a | nova-scheduler | nova-scheduler-5bcc764f79-wkfgl | internal | enabled | up    | 2023-05-31T12:16:20.000000 |
   | 872555ad-dd52-46ce-be01-1ec7f8af9cd9 | nova-conductor | nova-conductor-56dfd9749-fn9xb  | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | ff3710b8-f110-4949-b578-b09a1dbc19bb | nova-scheduler | nova-scheduler-5bcc764f79-5hcvx | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | d6831741-677e-471f-a019-66b46150cbcc | nova-scheduler | nova-scheduler-5bcc764f79-sfclc | internal | enabled | up    | 2023-05-31T12:16:20.000000 |
   | 792ec442-5e04-4a5f-9646-7cb0001dfb9c | nova-conductor | nova-conductor-56dfd9749-s5c6j  | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | 848f1573-3706-49ab-8c57-d6edf1631dce | nova-conductor | nova-conductor-56dfd9749-dfkgd  | internal | enabled | up    | 2023-05-31T12:16:21.000000 |
   | c5217922-bc1d-446e-a951-a4871d6020e3 | nova-compute   | compute2                        | nova     | enabled | up    | 2023-05-31T12:16:25.000000 |
   | 5f8cbde0-3c5f-404c-b31e-da443c1f14fd | nova-compute   | compute1                        | nova     | enabled | up    | 2023-05-31T12:16:25.000000 |
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+

* All services should be `enabled` and `up`.
* Each compute node should have nova-compute service.

Test
+++++

The command "btx --test"

* Creates a provider network and subnet.
  When it creates a provider network, it will ask for an address pool range.
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
   The first IP address to allocate (e.g. 192.168.22.100): 192.168.22.100
   Okay. I got the first address in the pool: 192.168.22.100
   The last IP address to allocate (e.g. 192.168.22.200): 192.168.22.108
   Okay. I got the last address of provider network pool: 192.168.22.108
   ...
   Instance status
   +------------------+------------------------------------------------------------------------------------+
   | Field            | Value                                                                              |
   +------------------+------------------------------------------------------------------------------------+
   | addresses        | public-net=192.168.22.104                                                          |
   | flavor           | disk='1', ephemeral='0', , original_name='m1.tiny', ram='512', swap='0', vcpus='1' |
   | image            | cirros (0b2787c1-fdb3-4a3c-ba9d-80208346a85c)                                      |
   | name             | test                                                                               |
   | status           | ACTIVE                                                                             |
   | volumes_attached | delete_on_termination='False', id='76edcae9-4b17-4081-8a23-26e4ad13787f'           |
   +------------------+------------------------------------------------------------------------------------+

Connect to the instance via provider network ip using ssh on the machine that 
has a provider network access.::

   (a node on provider network)$ ssh cirros@192.168.22.104
   cirros@192.168.22.104's password:
   $ ip address show dev eth0
   2: eth0:<BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc pfifo_fast qlen 1000
       link/ether fa:16:3e:ed:bc:7b brd ff:ff:ff:ff:ff:ff
       inet 192.168.22.104/24 brd 192.168.22.255 scope global eth0
          valid_lft forever preferred_lft forever
       inet6 fe80::f816:3eff:feed:bc7b/64 scope link
          valid_lft forever preferred_lft forever

Password is the default cirros password. 
(hint: password seems to be created by someone who loves Chicago Cubs
baseball team.)

