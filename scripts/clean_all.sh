#!/bin/bash

sudo scripts/clean_openstack_ns.sh
source ~/.envs/burrito/bin/activate
ansible-playbook --extra-vars=@vars.yml -b kubespray/reset.yml

