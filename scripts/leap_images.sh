#!/bin/bash

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
LOCAL_REGISTRY="localhost:5000"

IMAGES=$(cat ${CURRENT_DIR}/leap_images.txt)

for src in ${IMAGES}; do 
  repo=${src#*/}
  dst="${LOCAL_REGISTRY}/${repo}"
  echo "${src} => ${dst}"
  echo "== Pull ${src}"
  sudo ctr -n k8s.io images pull ${src} &> /dev/null
  echo "== Tag ${src} to ${dst}"
  sudo ctr -n k8s.io images tag ${src} ${dst}
  echo "== Push ${dst}"
  sudo ctr -n k8s.io images push --plain-http --platform linux/amd64 ${dst} &> /dev/null
  echo "== Delete ${src}"
  sudo ctr -n k8s.io images delete ${src}
  echo
done
