#!/bin/bash

set -e 

ACTION=${1:-""}

if [ "x${ACTION}" = "x-r" ]; then
  for p in patches/0[2-4,9]-patch*.txt patches/1[0,2,3,5-9]-patch*.txt; do
    if patch -sfRp0 --dry-run <${p} >/dev/null; then
      patch -Rp0 <${p}
    else
      echo "already reversed for ${p}"
    fi
  done
else
  for p in patches/0[2-4,9]-patch*.txt patches/1[0,2,3,5-9]-patch*.txt; do
    if patch -sNp0 --dry-run <${p} >/dev/null; then
      patch -Np0 <${p}
    else
      echo "already patched for ${p}"
    fi
  done
fi
