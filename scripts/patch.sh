#!/bin/bash

set -e 

ACTION=${1:-""}
REG_TMPL_DIR="kubespray/roles/kubernetes-apps/registry/templates"

if [ "x${ACTION}" = "x-r" ]; then
  rm -f ${REG_TMPL_DIR}/registry-certs.yml.j2
  for p in patches/0[2-4,9]-patch*.txt patches/1[0,2,7,8]-patch*.txt; do
    if patch -sfRp0 --dry-run <${p} >/dev/null; then
      patch -Rp0 <${p}
    else
      echo "already reversed for ${p}"
    fi
  done
else
  cp -f patches/${REG_TMPL_DIR}/registry-certs.yml.j2 \
    ${REG_TMPL_DIR}/registry-certs.yml.j2
  for p in patches/0[2-4,9]-patch*.txt patches/1[0,2,7,8]-patch*.txt; do
    if patch -sNp0 --dry-run <${p} >/dev/null; then
      patch -Np0 <${p}
    else
      echo "already patched for ${p}"
    fi
  done
fi
