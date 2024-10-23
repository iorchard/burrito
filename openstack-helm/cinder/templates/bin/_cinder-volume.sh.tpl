#!/bin/bash

{{/*
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

set -ex

# netapp/powerstore NFS storage init
{{- if .Values.bootstrap.enabled | default "echo 'Not Enabled'" }}
  {{- $volumeTypes := .Values.bootstrap.volume_types }}
  {{- range $name, $properties := $volumeTypes }}
    {{- if and $properties.dataLIF $properties.shares }}
      {{- $dataLIF := $properties.dataLIF }}
      {{- $shares := $properties.shares }}
      {{- range $share := $shares }}
        echo {{ $dataLIF }}:{{ $share }} >> /etc/cinder/share_{{ $name }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

# powerstore: get dellfcopy binary
{{- if .Values.powerstore_nfs_enabled }}
function get_file() {
  read -r proto server path <<<"$(printf '%s' "${1//// }")"
  d=/${path// //}
  h=${server//:*}
  p=${server//*:}
  [[ "${h}" = "${p}" ]] && p=80
  exec 3<>"/dev/tcp/${h}/${p}"
  printf 'GET %s HTTP/1.0\r\nHost: %s\r\n\r\n' "${d}" "${h}" >&3
  (while read -r line; do
    [ "$line" = $'\r' ] && break
  done && cat) <&3
  exec 3>&-
}
BINDIR="/usr/local/bin"
get_file "{{ .Values.dellfcopy_download_url }}" > "${BINDIR}/dellfcopy_bin"
chmod +x ${BINDIR}/dellfcopy_bin
# touch /etc/mtab - it is needed by dellfcopy
touch /etc/mtab
# create dellfcopy wrap script.
cat > ${BINDIR}/dellfcopy <<'EOF'
#!/bin/bash
# get nfs share to /etc/fstab - it is needed by dellfcopy
if shares=$(ls -1 /etc/cinder/share_* 2> /dev/null); then
  for s in $shares;do
    if [[ -z "${s}" ]]; then continue; fi
    fs=$(head -1 "${s}")
    m=$(grep "${fs} /var/lib/cinder/mnt" /proc/mounts|cut -d' ' -f2)
    if ! grep "${fs} ${m}" /etc/fstab &>/dev/null; then
      echo "${fs} ${m} nfs rw 0 0" >> /etc/fstab
    fi
  done
fi
/usr/local/bin/dellfcopy_bin ${@}
EOF
chmod +x ${BINDIR}/dellfcopy
{{- end }}

# override heartbeat_in_pthread variable
tee > /tmp/oslo_messaging_rabbit.conf << EOF
[oslo_messaging_rabbit]
heartbeat_in_pthread = false
EOF

exec cinder-volume \
     --config-file /etc/cinder/cinder.conf \
     --config-file /tmp/oslo_messaging_rabbit.conf \
     --config-file /etc/cinder/conf/backends.conf \
     --config-file /tmp/pod-shared/internal_tenant.conf
