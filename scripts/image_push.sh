#!/bin/bash

set -e

for src in $(cat images.txt); do
  repo=${src#*/}
  dst="${LOCAL_REGISTRY}/${repo}"
  echo "Pull ${src}"
  nerdctl pull $src &> /dev/null
  echo "Tag ${src} to ${dst}"
  nerdctl tag $src $dst
  echo "Push ${dst}"
  nerdctl --insecure-registry push $dst &> /dev/null
  echo "Delete ${src}"
  nerdctl rmi ${src} &> /dev/null
done
