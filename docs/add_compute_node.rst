Add a compute node
======================

This is a guide to add a compute node on the existing burrito cluster.

I assume the new compute node name is bon-compute2 and 
the IP address is 192.168.21.124

All the works are done on the ansible deployer.

Add compute2 hostname and IP in /etc/hosts.::

   $ sudo vi /etc/hosts
   192.168.21.124 bon-compute2

Copy the ssh key to bon-compute2.::

   $ ssh-copy-id bon-compute2

Edit inventory hosts to add the new compute node.::

   $ diff -u hosts.bak hosts
   --- hosts.bak        2023-02-20 13:54:45.365350417 +0900
   +++ hosts    2023-02-20 14:43:02.897660764 +0900
   @@ -1,6 +1,7 @@
    bon-controller ip=192.168.21.121 ansible_port=22 ansible_user=clex ansible_connection=local ansible_python_interpreter=/usr/bin/python3
    bon-compute ip=192.168.21.122 ansible_port=22 ansible_user=clex
    bon-storage ip=192.168.21.123 monitor_address=192.168.24.123 radosgw_address=192.168.24.123 ansible_port=22 ansible_user=clex
   +bon-compute2 ip=192.168.21.124 ansible_port=22 ansible_user=clex

    # ceph nodes
    [mons]
   @@ -18,14 +19,16 @@
    [clients]
    bon-controller
    bon-compute
   +bon-compute2

    # kubernetes nodes
    [kube_control_plane]
    bon-controller

    [kube_node]
    bon-controller
    bon-compute
   +bon-compute2

    # openstack nodes
    [controller-node]
   @@ -36,6 +39,7 @@

    [compute-node]
    bon-compute
   +bon-compute2


Check the connection to the new node bon-compute2.::

   $ ansible -m ping bon-compute2
   bon-compute2 | SUCCESS => {
       "ansible_facts": {
           "discovered_interpreter_python": "/usr/libexec/platform-python"
       },
       "changed": false,
       "ping": "pong"
   }

Run preflight playbook for bon-compute2.::

   $ ./run.sh preflight --limit=bon-compute2

Skip ha stack playbook since it is not the controller node.

Run ceph playbook.::

   $ ./run.sh ceph --limit=bon-compute2

Add the node to k8s cluster.::

   $ source ~/.envs/burrito/bin/activate
   $ ansible-playbook -i hosts --extra-vars=@vars.yml -b kubespray/scale.yml \
      --limit=bon-compute2

Check if the new node is added as a k8s node.::

   $ sudo kubectl get nodes
   NAME             STATUS   ROLES           AGE     VERSION
   bon-compute      Ready    <none>          3d15h   v1.24.8
   bon-compute2     Ready    <none>          3m39s   v1.24.8
   bon-controller   Ready    control-plane   3d15h   v1.24.8

Skip patch, registry playbook since it is the compute node.

Run burrito playbook with k8s-burrito and novakey-burrito tags.::

   $ ./run.sh burrito --tags=k8s-burrito,novakey-burrito

Check the node is added as a compute node.::

   root@btx-0:/# openstack compute service list
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   | ID                                   | Binary         | Host                            | Zone     | Status  | State | Updated At                 |
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   | e0a00939-3d0a-41d8-be9b-9dbb22ee5f11 | nova-scheduler | nova-scheduler-76c5874458-dlx8n | internal | enabled | down  | 2023-02-20T07:21:53.000000 |
   | 5d047fa1-0691-470a-803d-2df4a83dc1a3 | nova-conductor | nova-conductor-86c647ffdd-5l9md | internal | enabled | down  | 2023-02-20T07:21:53.000000 |
   | d7f9e8fc-13f5-4860-8573-116d09147850 | nova-compute   | bon-compute                     | nova     | enabled | up    | 2023-02-20T07:56:01.000000 |
   | 9b44d557-308e-4cd5-93c1-61843a2078da | nova-compute   | bon-compute2                    | nova     | enabled | up    | 2023-02-20T07:56:06.000000 |
   | 8f9aa838-0f4d-4029-b4df-9cbd89750723 | nova-scheduler | nova-scheduler-869cd8674d-7mcmp | internal | enabled | up    | 2023-02-20T07:56:03.000000 |
   | a1eae609-fa72-40f7-b7c4-300362a50fed | nova-conductor | nova-conductor-5c8f7fd658-6mbrp | internal | enabled | up    | 2023-02-20T07:56:04.000000 |
   +--------------------------------------+----------------+---------------------------------+----------+---------+-------+----------------------------+
   root@btx-0:/# openstack hypervisor list
   +----+---------------------+-----------------+----------------+-------+
   | ID | Hypervisor Hostname | Hypervisor Type | Host IP        | State |
   +----+---------------------+-----------------+----------------+-------+
   |  1 | bon-compute         | QEMU            | 192.168.21.122 | up    |
   |  2 | bon-compute2        | QEMU            | 192.168.21.124 | up    |
   +----+---------------------+-----------------+----------------+-------+


