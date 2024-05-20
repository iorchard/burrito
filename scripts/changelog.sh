#!/bin/bash

set -e

OLD=$1
NEW=$2

if [ -z ${OLD} ] || [ -z ${NEW} ]; then
  echo "Usage) $0 <from_tag_name> <to_tag_name>"
  echo
  exit 1
fi
git log --no-merges --pretty=format:"%s; (%ae)" ${OLD}...${NEW} | \
  sed 's/^\* //g;s/\*/;/g;s/^/* /g'
echo
