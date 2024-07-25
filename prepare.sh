#!/bin/bash

set -e 

OPT=${1:-"online"}
CFGFILES=(ansible.cfg hosts vars.yml)

if [ x"$OPT" = x"offline" ]; then
  sudo dnf -y install python39 gnutls-utils
  ./scripts/offline_services.sh --up
  python3.9 -m venv ~/.envs/burrito
  . ~/.envs/burrito/bin/activate
  pip install --no-index --find-links /mnt/pypi /mnt/pypi/{pip,wheel}-*
  pip install --no-index --find-links /mnt/pypi \
               --requirement requirements.txt
  pushd /mnt/ansible_collections
    [ -f pfx_req.yml ] && ansible-galaxy install --force -r pfx_req.yml || :
  popd
else
  sudo dnf -y install git python3 python39 python3-cryptography epel-release \
    gnutls-utils
  python3.9 -m venv ~/.envs/burrito
  . ~/.envs/burrito/bin/activate
  python -m pip install -U pip
  python -m pip install wheel
  python -m pip install -r requirements.txt
  ansible-galaxy install -r pfx_requirements.yml
fi

for CFG in ${CFGFILES[@]}; do
  if [ ! -f "${CFG}" ]; then
    cp ${CFG}.sample ${CFG}
  fi
done

if [ ! -d "group_vars" ]; then
  cp -a group_vars.sample group_vars
fi

./scripts/patch.sh
