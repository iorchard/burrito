#!/bin/bash

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
FILES_DIR_NAME="files"
FILES_DIR="${CURRENT_DIR}/${FILES_DIR_NAME}"
FILES_LIST="${CURRENT_DIR}/bin.txt"

if [ ! -f "${FILES_LIST}" ]; then
  echo "Abort: ${FILES_LIST} should exist."
  exit 1
fi
rm -rf "${FILES_DIR}"
mkdir -p "${FILES_DIR}"

# download files
wget -x -P "${FILES_DIR}" -i "${FILES_LIST}"

# get localrepo pod name
echo "Info: get local pod name."
pod=$(kubectl -n burrito get po -l k8s-app=localrepo -o jsonpath='{.items[0].metadata.name}')
if [ -z ${pod} ]; then
  echo "Abort: local repo pod is not found."
  exit 1
fi
# push to the local repo
echo "Info: copy the downloaded binaries to localrepo pod."
sudo kubectl -n burrito cp ${FILES_DIR} ${pod}:/usr/share/nginx/html/
