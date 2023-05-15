#!/bin/bash

set -e 

ACTION=${1:-""}

if [ "x${ACTION}" = "x-r" ]; then
  for p in patches/[0-9][0-9]-patch.txt; do
    if ! patch -sfp0 --dry-run <${p} >/dev/null; then
      patch -R -p0 <${p}
    else
      echo "already reversed for ${p}"
    fi
  done
else
  for p in patches/[0-9][0-9]-patch.txt; do
    if ! patch -Rsfp0 --dry-run <${p} >/dev/null; then
      patch -p0 <${p}
    else
      echo "already patched for ${p}"
    fi
  done
fi
