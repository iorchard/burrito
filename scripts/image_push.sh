#!/bin/bash

set -e

for src in $(cat images.txt); do
  repo=${src#*/}
  dst="${LOCAL_REGISTRY}/${repo}"
  #echo "${src} => ${dst}"
  echo "== Pull ${src}"
  #nerdctl pull ${src} &> /dev/null
  nerdctl pull ${src}
  echo "== Tag ${src} to ${dst}"
  nerdctl tag ${src} ${dst}
  echo "== Push ${dst}"
  #nerdctl --insecure-registry push ${dst} &> /dev/null
  nerdctl --insecure-registry push ${dst}
done
