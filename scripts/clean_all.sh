#!/bin/bash

sudo scripts/clean_openstack_ns.sh
ansible-playbook --extra-vars=@vars.yml -b kubespray/reset.yml

