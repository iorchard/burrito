---
# MDM VIP (at least 2 VIPs on storage networks are recommended)
mdm_ip: 
  - "192.168.24.40"
  - "192.168.25.40"
storage_iface_names:
  - eth4
  - eth5
sds_devices:
  - /dev/sdb
  - /dev/sdc
  - /dev/sdd
gateway_admin_password: "{{ vault_pfx_admin_password }}"
mdm_password: "{{ vault_pfx_admin_password }}"

#
# Do Not Edit below
#
pkg_url_base: "file://{{ ansible_env.HOME }}/powerflex_rpms"
pkg_url:
  lia: "{{ pkg_url_base }}/EMC-ScaleIO-lia-3.6-700.103.el8.x86_64.rpm"
  mdm: "{{ pkg_url_base }}/EMC-ScaleIO-mdm-3.6-700.103.el8.x86_64.rpm"
  sds: "{{ pkg_url_base }}/EMC-ScaleIO-sds-3.6-700.103.el8.x86_64.rpm"
  sdc: "{{ pkg_url_base }}/EMC-ScaleIO-sdc-3.6-700.103.el8.x86_64.rpm"
  gateway: "{{ pkg_url_base }}/EMC-ScaleIO-gateway-3.6-700.103.x86_64.rpm"
  presentation: "{{ pkg_url_base }}/EMC-ScaleIO-mgmt-server-3.6-700.101.noarch.rpm"
lia_token: "{{ vault_pfx_lia_token }}"
protection_domain_name: "burrito_domain"
storage_pool_name: "burrito_sp"
# default gateway http port is 80. We are changing to 8999
gateway_http_port: 8999
# default gateway ssl port is 443. We are changing to 7443
gateway_ssl_port: 7443
# default lia port is 9099. We are changing to 9090
lia_port: 9090
# default presentation port is 8443. We are changing to 9443
presentation_port: 9443
...
