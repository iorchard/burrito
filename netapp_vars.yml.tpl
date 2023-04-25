---
netapp:
  - name: netapp1
    managementLIF: "192.168.100.230"
    dataLIF: "192.168.140.19"
    svm: "svm01"
    username: "admin"
    password: "<netapp_admin_password>"
    nfsMountOptions: "nfsvers=4,lookupcache=pos"
    shares:
      - /dev03
...
