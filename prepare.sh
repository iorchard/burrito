#!/bin/bash

set -e 

OPT=${1:-"online"}
CFGFILES=(ansible.cfg hosts vars.yml)

PKG_MGR=
COMMON_PKGS="git python3 python3-cryptography"
OFFLINE_PKGS=
ONLINE_PKGS=
PYTHON_CMD=
function get_package_manager() {
  [ -f /etc/os-release ] && . /etc/os-release || (echo 'Cannot find /etc/os-release'; exit 1)
  case $ID in
    debian)
      COMMON_PKGS="$COMMON_PKGS python3-venv"
      PKG_MGR="apt"
      PYTHON_CMD="python3"
      sudo $PKG_MGR update
      ;;
    rocky)
      OFFLINE_PKGS="python3.12"
      ONLINE_PKGS="python3.12 epel-release"
      PKG_MGR="dnf"
      PYTHON_CMD="python3.12"
      ;;
    *)
      echo "Unsupported linux distro."
      exit 1
      ;;
  esac
}
get_package_manager

if [ x"$OPT" = x"offline" ]; then
  ./scripts/offline_services.sh --up
  [ ! -z $OFFLINE_PKGS ] && sudo $PKG_MGR -y install $OFFLINE_PKGS || :
  $PYTHON_CMD -m venv ~/.envs/burrito
  . ~/.envs/burrito/bin/activate
  pip install --no-index --find-links /mnt/pypi /mnt/pypi/{pip,wheel}-*
  pip install --no-index --find-links /mnt/pypi \
               --requirement requirements.txt
  pushd /mnt/ansible_collections
    [ -f pfx_req.yml ] && ansible-galaxy install --force -r pfx_req.yml || :
  popd
else
  sudo ${PKG_MGR} -y install ${COMMON_PKGS} ${ONLINE_PKGS}
  $PYTHON_CMD -m venv ~/.envs/burrito
  . ~/.envs/burrito/bin/activate
  python -m pip install -U pip
  python -m pip install wheel
  python -m pip install -r requirements.txt
  ansible-galaxy install -r pfx_requirements.yml
fi

./scripts/patch.sh

for CFG in ${CFGFILES[@]}; do
  if [ ! -f "${CFG}" ]; then
    cp ${CFG}.sample ${CFG}
  fi
done

if [ ! -d "group_vars" ]; then
  cp -a group_vars.sample group_vars
fi

