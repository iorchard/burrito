---
# storage model: See hitachi_prefix_id below for your storage model
hitachi_storage_model: vsp_e990

## k8s storageclass variables
# Get hitachi storage serial number
hitachi_serial_number: "<serial_number>"
hitachi_pool_id: "0"
# port_id to be used by k8s PV
hitachi_port_id: "CL4-A"

## openstack cinder variables
hitachi_san_ip: "<san_ip>"
hitachi_san_login: "<san_login>"
hitachi_san_password: "<san_password>"
hitachi_ldev_range: "00:10:00-00:10:FF"
hitachi_target_ports: "CL3-A"
hitachi_compute_target_ports: "CL1-A,CL2-A,CL3-A,CL5-A,CL6-A"

########################
# Do Not Edit below!!! #
########################

## openstack cinder variables
hitachi_storage_id: "{{ hitachi_prefix_id[hitachi_storage_model] }}{{ hitachi_serial_number }}"
hitachi_pool: "{{ hitachi_pool_id }}"

## the Hitachi Service Processor variables
hsvp_url: "http://{{ hitachi_san_ip }}"
hsvp_user: "{{ hitachi_san_login }}"
hsvp_password: "{{ hitachi_san_password }}"

## Hitachi prefix id
hitachi_prefix_id:
  vsp_e990: 936000
  vsp_e590: 934000
  vsp_e780: 934000
  vsp_f370: 886000
  vsp_f700: 886000
  vsp_f900: 886000
  vsp_g370: 886000
  vsp_g700: 886000
  vsp_g900: 886000
  vsp_f350: 882000
  vsp_g350: 882000
...
