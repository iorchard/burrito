#!/bin/bash

set -e

SRC_VER="${1:-1.0.0}"
REL_NAME="${SRC_VER//\//_}"

function USAGE() {
  echo "USAGE: $0 <git_tag>" 1>&2
  echo
  echo "ex) $0 1.0.0"
  echo
}

if [ $# -lt 1 ];then
  USAGE
  exit 1
fi

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
DIST_DIR=${CURRENT_DIR}/dist

curl -sLo ${CURRENT_DIR}/git-archive-all.sh \
  https://raw.githubusercontent.com/fabacab/git-archive-all.sh/master/git-archive-all.sh
chmod +x ${CURRENT_DIR}/git-archive-all.sh

git clone --recursive -b ${SRC_VER} https://github.com/iorchard/burrito.git \
  ${DIST_DIR}/burrito
pushd ${DIST_DIR}/burrito
  echo ${SRC_VER} \($(git rev-parse HEAD)\) > VERSION
  ${CURRENT_DIR}/git-archive-all.sh --prefix burrito-${REL_NAME}/ \
    ${DIST_DIR}/burrito-${REL_NAME}.tar
  # add VERSION to tarball
  tar --xform="s#^#burrito-${REL_NAME}/#" -rf \
    ${DIST_DIR}/burrito-${REL_NAME}.tar VERSION
  # compress
  gzip -9f ${DIST_DIR}/burrito-${REL_NAME}.tar
popd
rm -fr ${DIST_DIR}/burrito
