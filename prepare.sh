#!/bin/bash

set -e 

OPT=${1:-"online"}

if [ x"$OPT" = x"offline" ]; then 
  pushd /mnt/ansible_collections
    ansible-galaxy install --force -r requirements.yml
  popd
else
  python -m pip install -U pip
  python -m pip install wheel
  python -m pip install -r requirements.txt
  ansible-galaxy install -r ceph-ansible/requirements.yml
fi

cp ansible.cfg.sample ansible.cfg
cp hosts.sample hosts
cp vars.yml.sample vars.yml

mkdir -p group_vars/all
cp ceph_vars.yml.tpl group_vars/all/ceph_vars.yml
cp netapp_vars.yml.tpl group_vars/all/netapp_vars.yml

