#!/bin/bash

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
FILES_DIR_NAME="leap_files"
FILES_DIR="${CURRENT_DIR}/${FILES_DIR_NAME}"
FILES_LIST="${CURRENT_DIR}/leap_bin.txt"

if [ ! -f "${FILES_LIST}" ]; then
  echo "Abort: ${FILES_LIST} should exist."
  exit 1
fi
rm -rf "${FILES_DIR}"
mkdir -p "${FILES_DIR}"

# download files
wget -x -P "${FILES_DIR}" -i "${FILES_LIST}"

# push to the iso mountpoint
echo "Info: copy the downloaded binaries to iso mountpoint."
sudo rsync -av ${FILES_DIR}/ /mnt/files/
