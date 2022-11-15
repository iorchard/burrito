#!/bin/bash

python -m pip install -U pip
python -m pip install wheel
python -m pip install -r requirements.txt
ansible-galaxy install -r ceph-ansible/requirements.yml


cp ansible.cfg.sample ansible.cfg
cp hosts.sample hosts
cp vars.yml.sample vars.yml

