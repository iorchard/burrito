#!/bin/bash

pushd /mnt/ansible_collections
  ansible-galaxy install --force -r requirements.yml
popd

cp ansible.cfg.sample ansible.cfg
cp hosts.sample hosts
cp vars.yml.sample vars.yml

