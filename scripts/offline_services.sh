#!/bin/bash

set -e

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
REPO_PORT=8001
REGISTRY_PORT=5000
EXIT_CODE=0
U=

function check() {
  read -p "Enter management network interface name: " MGMT_IFACE
  # check MGMT_IFACE exists
  if ! ip -br a s dev ${MGMT_IFACE}; then
    echo "Cannot find the network interface name: $MGMT_IFACE"
    exit 1
  fi
  # get mgmt iface ip address
  MGMT_IP=$(ip -br a s dev ${MGMT_IFACE} | awk '{print $3}' |cut -d'/' -f1)
}
function status() {
  if sudo lsof -i TCP:${REPO_PORT} &>/dev/null; then
    echo "Local repo is running."
    ps -q $(sudo lsof -i TCP:${REPO_PORT} -t) -o cmd=
  else
    echo "Local repo is NOT running."
    EXIT_CODE=1
  fi
  echo
  if sudo lsof -i TCP:${REGISTRY_PORT} &>/dev/null; then
    echo "Local registry is running."
    ps -q $(sudo lsof -i TCP:${REGISTRY_PORT} -t) -o cmd=
  else
    echo "Local registry is NOT running."
    EXIT_CODE=1
  fi
  echo
  exit ${EXIT_CODE}
}

function repo_down() {
  if sudo lsof -i TCP:${REPO_PORT} &>/dev/null; then
    U=$(ps -q $(sudo lsof -i TCP:${REPO_PORT} -t) -o user=)
  fi
  if [ "x${U}" = "xhaproxy" ]; then
    echo "I can do nothing: Local repo is already taken over by haproxy."
    EXIT_CODE=10
    exit $EXIT_CODE
  else
    if sudo lsof -i TCP:${REPO_PORT} &>/dev/null; then
      kill $(sudo lsof -i TCP:${REPO_PORT} -t)
    fi
  fi
}
function registry_down() {
  if sudo lsof -i TCP:${REGISTRY_PORT} &>/dev/null; then
    U=$(ps -q $(sudo lsof -i TCP:${REGISTRY_PORT} -t) -o user=)
  fi
  if [ "x${U}" = "xhaproxy" ]; then
    echo "I can do nothing: Local registry is already taken over by haproxy."
    EXIT_CODE=10
    exit $EXIT_CODE
  else
    if sudo lsof -i TCP:${REGISTRY_PORT} &>/dev/null; then
      kill $(sudo lsof -i TCP:${REGISTRY_PORT} -t)
    fi
  fi
}
function up() {
  check
  if [[ $# -eq 0 ]]; then
    repo_up
    registry_up
  elif [[ "$1" == "repo" ]]; then
    repo_up
  elif [[ "$1" == "registry" ]]; then
    registry_up
  fi
  echo "Started offline repo and/or registry services."
  echo "Put offline flag."
  touch ${CURRENT_DIR}/../.offline_flag
}
function down() {
  if [[ $# -eq 0 ]]; then
    repo_down
    registry_down
  elif [[ "$1" == "repo" ]]; then
    repo_down
  elif [[ "$1" == "registry" ]]; then
    registry_down
  fi
  echo "Stopped repo and/or registry services."
  echo "Remove offline flag."
  rm -f ${CURRENT_DIR}/../.offline_flag
}
function repo_up() {
  repo_down
  pushd /mnt
    nohup python3 -m http.server --bind ${MGMT_IP} ${REPO_PORT} \
      &>/tmp/repo.log &
  popd
  cat <<EOF > /tmp/burrito.repo.tmp
[burrito]
name=Burrito Repo
baseurl=http://${MGMT_IP}:${REPO_PORT}/BaseOS
enabled=1
gpgcheck=0
module_hotfixes=1
EOF

  if [ -f /tmp/burrito.repo.tmp ]; then
    if [ -f /etc/yum.repos.d/burrito.repo ]; then
      if ! diff /tmp/burrito.repo.tmp /etc/yum.repos.d/burrito.repo; then
        sudo mv /etc/yum.repos.d /etc/yum.repos.d.$(date +%Y%m%d-%H%M%S)
        sudo mkdir /etc/yum.repos.d
        sudo mv /tmp/burrito.repo.tmp /etc/yum.repos.d/burrito.repo
      fi
    else
      sudo mv /etc/yum.repos.d /etc/yum.repos.d.$(date +%Y%m%d-%H%M%S)
      sudo mkdir /etc/yum.repos.d
      sudo mv /tmp/burrito.repo.tmp /etc/yum.repos.d/burrito.repo
    fi   
  fi
}
function registry_up() {
  registry_down
  # Run registry server
  cat <<EOF > /tmp/config.yml
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /mnt/registry
http:
  addr: ${MGMT_IP}:${REGISTRY_PORT}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
compatibility:
  schema1:
    enabled: true
EOF
  pushd /tmp
    tar xzf /mnt/files/github.com/distribution/distribution/releases/download/v*/registry*.tar.gz registry
  popd
  nohup /tmp/registry serve /tmp/config.yml &>/tmp/registry.log &
}
function USAGE() {
  echo "USAGE: $0 [-h|-d|-u]" 1>&2
  echo 
  echo " -h --help                   Display this help message."
  echo " -s --status                 Show the status of offline services."
  echo " -d --down   [repo|registry] Stop the offline services."
  echo " -u --up     [repo|registry] Start the offline services."
  echo 
}
if [ $# -lt 1 ]; then
  USAGE
  exit 1
fi

OPT=$1
shift
while true
do
  case "$OPT" in
    -h | --help)
      USAGE
      exit 0
      ;;
    -s | --status)
      status
      break
      ;;
    -u | --up)
      up "$@"
      break
      ;;
    -d | --down)
      down "$@"
      break
      ;;
    *)
      echo Error: unknown option: "$OPT" 1>&2
      echo " "
      USAGE
      exit 1
      ;;
  esac
done
