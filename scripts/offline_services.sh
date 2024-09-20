#!/bin/bash

set -e

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
REPO_PORT=8001
REGISTRY_PORT=5000
REGISTRY_CERT_DIR="/etc/ssl/registry"
EXIT_CODE=0
U=
MGMT_IP=

function check() {
  if [ -f ${CURRENT_DIR}/.mgmt_ip ]; then
    MGMT_IP=$(head -1 ${CURRENT_DIR}/.mgmt_ip)
  else
    read -p "Enter management network interface name: " MGMT_IFACE
    # check MGMT_IFACE exists
    if ! ip -br a s dev ${MGMT_IFACE}; then
      echo "Cannot find the network interface name: $MGMT_IFACE" 1>&2
      exit 1
    fi
    # get mgmt iface ip address
    MGMT_IP=$(ip -br a s dev ${MGMT_IFACE} | awk '{print $3}' |cut -d'/' -f1)
    # save MGMT_IP to .mgmt_ip
    echo ${MGMT_IP} > ${CURRENT_DIR}/.mgmt_ip
  fi
}
function _pids() {
  if [ ! -f ${CURRENT_DIR}/.mgmt_ip ]; then
    echo "Cannot get management ip address. Run $0 --up first." 1>&2
    exit 1
  fi
  MGMT_IP=$(head -1 ${CURRENT_DIR}/.mgmt_ip)
  # check REPO_PORT is bound to haproxy.
  REPO_PID=$(sudo lsof -i TCP:${REPO_PORT} -t|head -1)
  REGISTRY_PID=$(sudo lsof -i TCP:${REGISTRY_PORT} -t|head -1)
}
function status() {
  _pids
  if [ -n "${REPO_PID}" ]; then
    echo "Local repo is running."
    ps -q ${REPO_PID} -o cmd=
  else
    echo "Local repo is NOT running." 1>&2
    EXIT_CODE=1
  fi
  echo

  if [ -n "${REGISTRY_PID}" ]; then
    echo "Local registry is running."
    ps -q ${REGISTRY_PID} -o cmd=
  else
    echo "Local registry is NOT running." 1>&2
    EXIT_CODE=1
  fi
  echo
  exit ${EXIT_CODE}
}

function repo_down() {
  _pids
  if [ -n "${REPO_PID}" ]; then
    U=$(ps -q ${REPO_PID} -o user=)
    if [ "x${U}" != "xhaproxy" ]; then
      kill ${REPO_PID}
      echo "Stopped local repo."
    else
      echo "I can do nothing: Local repo is already taken over by haproxy."
    fi
  fi
}
function registry_down() {
  _pids
  if [ -n "${REGISTRY_PID}" ]; then
    U=$(ps -q ${REGISTRY_PID} -o user=)
    if [ "x${U}" != "xhaproxy" ]; then
      sudo kill ${REGISTRY_PID}
      echo "Stopped local registry."
    else
      echo "I can do nothing: Local registry is already taken over by haproxy."
    fi
  fi
}
function up() {
  check
  if [ $# -eq 0 ]; then
    repo_up
    registry_up
  elif [ "$1" == "repo" ]; then
    repo_up
  elif [ "$1" == "registry" ]; then
    registry_up
  fi
  echo "Started offline repo and/or registry services."
  echo "Put offline flag."
  touch ${CURRENT_DIR}/../.offline_flag
}
function down() {
  if [ $# -eq 0 ]; then
    repo_down
    registry_down
  elif [ "$1" == "repo" ]; then
    repo_down
  elif [ "$1" == "registry" ]; then
    registry_down
  fi
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
function create_seed_registry_cert() {
  if [ -f ${REGISTRY_CERT_DIR}/ca.pem -a \
       -f ${REGISTRY_CERT_DIR}/seed-registry-key.pem -a \
       -f ${REGISTRY_CERT_DIR}/seed-registry.pem \
     ]; then
    return
  fi
  certtool --generate-privkey | sudo tee ${REGISTRY_CERT_DIR}/ca-key.pem
  cat <<EOF | sudo tee ${REGISTRY_CERT_DIR}/ca.info
cn = "Registry"
expiration_days = 3650
ca
cert_signing_key
EOF
  sudo certtool --generate-self-signed --bits=4096 \
        --load-privkey ${REGISTRY_CERT_DIR}/ca-key.pem \
        --template ${REGISTRY_CERT_DIR}/ca.info \
        --outfile ${REGISTRY_CERT_DIR}/ca.pem
  sudo certtool --generate-privkey \
        --outfile ${REGISTRY_CERT_DIR}/seed-registry-key.pem
  cat <<EOF | sudo tee ${REGISTRY_CERT_DIR}/seed-registry.info
organization = "Seed Registry"
cn = "seed-registry"
expiration_days = 3650
tls_www_server
encryption_key
signing_key
EOF
  sudo certtool --generate-certificate \
        --load-privkey ${REGISTRY_CERT_DIR}/seed-registry-key.pem \
        --load-ca-certificate ${REGISTRY_CERT_DIR}/ca.pem \
        --load-ca-privkey ${REGISTRY_CERT_DIR}/ca-key.pem \
        --template ${REGISTRY_CERT_DIR}/seed-registry.info \
        --outfile ${REGISTRY_CERT_DIR}/seed-registry.pem
}
function registry_up() {
  # down the registry if it is running.
  registry_down
  # create TLS certificate
  sudo mkdir -p $REGISTRY_CERT_DIR
  create_seed_registry_cert
  # Create a random registry secret
  REGISTRY_SECRET=$(head /dev/urandom |tr -dc A-Za-z0-9 |head -c 16)
  # Run registry server
  cat <<EOF > /tmp/seed_registry.conf
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
  addr: 0.0.0.0:${REGISTRY_PORT}
  headers:
    X-Content-Type-Options: [nosniff]
  secret: ${REGISTRY_SECRET}
  tls:
    certificate: ${REGISTRY_CERT_DIR}/seed-registry.pem
    key: ${REGISTRY_CERT_DIR}/seed-registry-key.pem
health:
  storagedriver:
    enabled: false
compatibility:
  schema1:
    enabled: true
EOF
  pushd /usr/bin
    sudo tar xzf /mnt/files/github.com/distribution/distribution/releases/download/v*/registry*.tar.gz registry
  popd
  nohup sudo /usr/bin/registry serve /tmp/seed_registry.conf &>/tmp/registry.log &
}
function USAGE() {
  cat <<EOF 1>&2
USAGE: $0 [-h|-d|-u]

 -h --help                   Display this help message.
 -s --status                 Show the status of offline services.
 -d --down   [repo|registry] Stop the offline services.
 -u --up     [repo|registry] Start the offline services.

EOF

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
    -c | --check)
      check
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
      USAGE
      exit 1
      ;;
  esac
done
