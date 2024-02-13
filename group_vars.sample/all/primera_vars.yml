---
# Primera storage IP address
primera_ip: "192.168.200.178"
# Primera username/password
primera_username: "3paradm"
primera_password: "<PASSWORD>"
# Primera common provisioning group for kubernetes
primera_k8s_cpg: "<cpg_for_k8s>"
# Primera common provisioning group for openstack cinder
primera_openstack_cpg: "<cpg_for_openstack>"

########################
# Do Not Edit below!!! #
########################
# k8s variables
primera_secret:
  name: "primera-secret"
  service_name: "primera3par-csp-svc"
  service_port: "8080"
  backend: "{{ primera_ip }}"
  username: "{{ primera_username }}"
  password: "{{ primera_password }}"
# cinder variables
primera_volume_driver: cinder.volume.drivers.hpe.hpe_3par_fc.HPE3PARFCDriver
primera_api_url: "https://{{ primera_ip }}/api/v1"

# image versions
primera_csi_version: "v2.4.0"
primera_csi_extension_version: "v1.2.5"
primera_volume_mutator_version: "v1.3.4"
primera_volume_group_snapshotter_version: "v1.0.4"
primera_volume_group_provisioner_version: "v1.0.4"
...
