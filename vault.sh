#!/bin/bash

set -e

if [ -f .vaultpass ]; then
  echo "Error: .vaultpass file exists. Remove it first."
  exit 1
fi
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
VAULTFILE="${CURRENT_DIR}/group_vars/all/vault.yml"
NOVA_SSH_KEY="/tmp/nova_sshkey"
PASSLENGTH=12
COMP="A-Za-z0-9"

# Create vault file
mkdir -p $(dirname "${VAULTFILE}")
read -s -p "$USER password: " USERPASS; echo ""
read -s -p 'openstack admin password: ' OS_ADMIN_PASS; echo ""
MARIADB_ROOT_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
RABBITMQ_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
CEPH_SECRET_UUID=$(cat /proc/sys/kernel/random/uuid)
KEYSTONE_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
GLANCE_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
PLACEMENT_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
NEUTRON_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
NOVA_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
CINDER_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
HORIZON_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
BARBICAN_PASS=$(head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH})
BARBICAN_KEK=$(head /dev/urandom |tr -dc ${COMP} |head -c 32)
ssh-keygen -f ${NOVA_SSH_KEY} -C 'nova-ssh-public-key' -N '' &> /dev/null

echo "---" > $VAULTFILE
echo "vault_ssh_password: '$USERPASS'" >> $VAULTFILE
echo "vault_sudo_password: '$USERPASS'" >> $VAULTFILE
echo "vault_openstack_admin_password: '$OS_ADMIN_PASS'" >> $VAULTFILE
echo "vault_mariadb_root_password: '$MARIADB_ROOT_PASS'" >> $VAULTFILE
echo "vault_rabbitmq_openstack_password: '$RABBITMQ_PASS'" >> $VAULTFILE
echo "vault_ceph_secret_uuid: '$CEPH_SECRET_UUID'" >> $VAULTFILE
echo "vault_keystone_password: '$KEYSTONE_PASS'" >> $VAULTFILE
echo "vault_glance_password: '$GLANCE_PASS'" >> $VAULTFILE
echo "vault_placement_password: '$PLACEMENT_PASS'" >> $VAULTFILE
echo "vault_neutron_password: '$NEUTRON_PASS'" >> $VAULTFILE
echo "vault_cinder_password: '$CINDER_PASS'" >> $VAULTFILE
echo "vault_nova_password: '$NOVA_PASS'" >> $VAULTFILE
echo "vault_horizon_password: '$HORIZON_PASS'" >> $VAULTFILE
echo "vault_barbican_password: '$BARBICAN_PASS'" >> $VAULTFILE
echo "vault_barbican_kek: '$BARBICAN_KEK'" >> $VAULTFILE
echo "vault_pfx_admin_password: '$OS_ADMIN_PASS'" >> $VAULTFILE
echo "vault_pfx_lia_token: '$OS_ADMIN_PASS'" >> $VAULTFILE
echo "vault_nova_ssh_private_key: |" >> $VAULTFILE
sed 's/^/  /g' ${NOVA_SSH_KEY} >> $VAULTFILE
echo "vault_nova_ssh_public_key: >" >> $VAULTFILE
sed 's/^/  /g' ${NOVA_SSH_KEY}.pub >> $VAULTFILE
echo -n "..." >> $VAULTFILE
rm -f ${NOVA_SSH_KEY} ${NOVA_SSH_KEY}.pub

head /dev/urandom |tr -dc ${COMP} |head -c ${PASSLENGTH} > .vaultpass
chmod 0400 .vaultpass
sudo chattr +i .vaultpass
ansible-vault encrypt $VAULTFILE
