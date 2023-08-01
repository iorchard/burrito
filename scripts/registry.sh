#!/bin/bash

echo "local registry: ${LOCAL_REGISTRY}"
echo "seed registry: ${SEED_REGISTRY}"
echo "offline: ${OFFLINE}"

IMAGES=$(cat images.txt $([ "${INCLUDE_PFX}" = 1 ] && echo -n pfx_images.txt || :))
for src in ${IMAGES}; do
  if [ "${OFFLINE}" = "1" ]; then
    registry=${src%%/*}
    src=${src/${registry}/${SEED_REGISTRY}}
  fi
  repo=${src#*/}
  dst="${LOCAL_REGISTRY}/${repo}"
  echo "${src} => ${dst}"
  echo "== Pull ${src}"
  nerdctl pull ${src} &> /dev/null
  echo "== Tag ${src} to ${dst}"
  nerdctl tag ${src} ${dst}
  echo "== Push ${dst}"
  nerdctl --insecure-registry push ${dst} &> /dev/null
  echo "== Delete ${src} and ${dst}"
  nerdctl rmi --force ${src} ${dst}
done
