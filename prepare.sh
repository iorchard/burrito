#!/bin/bash

set -e 

OPT=${1:-"online"}
CFGFILES=(ansible.cfg hosts vars.yml)

if [ x"$OPT" = x"offline" ]; then
  ./scripts/offline_services.sh --up
  sudo dnf -y install python39
  python3.9 -m venv ~/.envs/burrito
  . ~/.envs/burrito/bin/activate
  pip install --no-index --find-links /mnt/pypi /mnt/pypi/{pip,wheel}-*
  pip install --no-index --find-links /mnt/pypi \
               --requirement requirements.txt
  pushd /mnt/ansible_collections
    [ -f ceph-ansible_req.yml ] && ansible-galaxy install --force -r ceph-ansible_req.yml || :
    [ -f pfx_req.yml ] && ansible-galaxy install --force -r pfx_req.yml || :
  popd
else
  sudo dnf -y install git python3 python39 python3-cryptography epel-release
  python3.9 -m venv ~/.envs/burrito
  . ~/.envs/burrito/bin/activate
  python -m pip install -U pip
  python -m pip install wheel
  python -m pip install -r requirements.txt
  ansible-galaxy install -r ceph-ansible/requirements.yml
  ansible-galaxy install -r pfx_requirements.yml
fi

for CFG in ${CFGFILES[@]}; do
  if [ ! -f "${CFG}" ]; then
    cp ${CFG}.sample ${CFG}
  fi
done

if [ ! -d "group_vars" ]; then
  mkdir -p group_vars/all
  cp ceph_vars.yml.tpl group_vars/all/ceph_vars.yml
  cp netapp_vars.yml.tpl group_vars/all/netapp_vars.yml
  cp powerflex_vars.yml.tpl group_vars/all/powerflex_vars.yml
  cp hitachi_vars.yml.tpl group_vars/all/hitachi_vars.yml
  cp lvm_vars.yml.tpl group_vars/all/lvm_vars.yml
fi

./scripts/patch.sh
