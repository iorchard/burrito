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
# update nfs.py
cp /var/lib/openstack/lib/python3.10/site-packages/cinder/volume/drivers/dell_emc/powerstore/nfs.py /var/lib/openstack/lib/python3.10/site-packages/cinder/volume/drivers/dell_emc/powerstore/nfs.py.bak
cat > /var/lib/openstack/lib/python3.10/site-packages/cinder/volume/drivers/dell_emc/powerstore/nfs.py <<'EOF'
# Copyright (c) 2020 Dell Inc. or its subsidiaries.
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import collections
import errno
import os

from oslo_concurrency import processutils as putils
from oslo_config import cfg
from oslo_log import log as logging

from cinder import coordination
from cinder import exception
from cinder.i18n import _
from cinder.image import image_utils
from cinder import interface
from cinder.volume import configuration
from cinder.volume.drivers.nfs import nfs_opts
from cinder.volume.drivers.nfs import NfsDriver


LOG = logging.getLogger(__name__)


CONF = cfg.CONF
CONF.register_opts(nfs_opts, group=configuration.SHARED_CONF_GROUP)


class PowerStoreNFSDriverInitialization(NfsDriver):
    """Implementation of PowerStoreNFSDriver initialization.

    Added multiattach support option and checking that the required
    packages are installed.
    """
    driver_volume_type = 'nfs'
    driver_prefix = 'nfs'
    volume_backend_name = 'PowerStore_NFS'
    VERSION = '1.0.0'
    VENDOR = 'Dell'

    # ThirdPartySystems wiki page
    CI_WIKI_NAME = "DellEMC_PowerStore_CI"

    def __init__(self, execute=putils.execute, *args, **kwargs):
        super(PowerStoreNFSDriverInitialization, self).__init__(
            execute, *args, **kwargs)
        self.multiattach_support = False

    def do_setup(self, context):
        super(PowerStoreNFSDriverInitialization, self).do_setup(context)
        self._check_multiattach_support()

    def _check_multiattach_support(self):
        """Enable multiattach support if nfs_qcow2_volumes disabled."""

        self.multiattach_support = not self.configuration.nfs_qcow2_volumes
        if not self.multiattach_support:
            msg = _("Multi-attach feature won't work "
                    "with qcow2 volumes enabled for nfs")
            LOG.warning(msg)

    def _check_package_is_installed(self, package):
        try:
            self._execute(package, check_exit_code=False,
                          run_as_root=False)
        except OSError as exc:
            if exc.errno == errno.ENOENT:
                msg = _('%s is not installed') % package
                raise exception.VolumeDriverException(msg)
            else:
                raise

    def check_for_setup_error(self):
        self._check_package_is_installed('dellfcopy')

    def _update_volume_stats(self):
        super(PowerStoreNFSDriverInitialization, self)._update_volume_stats()
        self._stats["vendor_name"] = self.VENDOR
        self._stats['multiattach'] = self.multiattach_support


@interface.volumedriver
class PowerStoreNFSDriver(PowerStoreNFSDriverInitialization):
    """Dell PowerStore NFS Driver.

    .. code-block:: none

      Version history:
        1.0.0 - Initial version
    """

    @coordination.synchronized('{self.driver_prefix}-{volume[id]}')
    def delete_volume(self, volume):
        """Deletes a logical volume."""

        if not volume.provider_location:
            LOG.warning("Volume %s does not have provider_location "
                        "specified, skipping", volume.name)
            return

        self._ensure_share_mounted(volume.provider_location)

        info_path = self._local_path_volume_info(volume)
        info = self._read_info_file(info_path, empty_if_missing=True)

        if info:
            base_snap_path = os.path.join(self._local_volume_dir(volume),
                                          info['active'])
            self._delete(info_path)
            self._delete(base_snap_path)

        base_volume_path = self._local_path_volume(volume)
        self._delete(base_volume_path)

    def _extend_volume(self, volume, new_size):
        """Extend an existing volume to the new size."""

        if self._is_volume_attached(volume):
            msg = (_("Cannot extend volume %s while it is attached")
                   % volume.name_id)
            raise exception.ExtendVolumeError(msg)

        LOG.info("Extending volume %s.", volume.name_id)
        extend_by = int(new_size) - volume.size
        if not self._is_share_eligible(volume.provider_location,
                                       extend_by):
            raise exception.ExtendVolumeError(
                reason="Insufficient space to extend "
                       "volume %s to %sG" % (volume.name_id, new_size)
            )

        path = self.local_path(volume)
        info = self._qemu_img_info(path, volume.name)
        backing_fmt = info.file_format

        if backing_fmt not in ['raw', 'qcow2']:
            msg = _("Unrecognized backing format: %s") % backing_fmt
            raise exception.InvalidVolume(msg)

        image_utils.resize_image(path, new_size)

    def create_cloned_volume(self, volume, src_vref):
        return self._create_cloned_volume(volume, src_vref)

    def _do_fast_clone_file(self, volume_path, new_volume_path):
        """Fast clone a file using a dellfcopy package."""

        command = ['dellfcopy', '-o', 'fastclone', '-s', volume_path,
                   '-d', new_volume_path, '-v', '1']
        try:
            LOG.info('Cloning file from %s to %s',
                     volume_path, new_volume_path)
            self._execute(*command, run_as_root=self._execute_as_root)
            LOG.info('Cloning volume: %s succeeded', volume_path)
        except putils.ProcessExecutionError:
            raise

    def _create_volume_from_snapshot(self, volume, snapshot):
        """Creates a volume from a snapshot."""

        LOG.debug("Creating volume %(vol)s from snapshot %(snap)s",
                  {'vol': volume.name_id, 'snap': snapshot.id})

        volume.provider_location = self._find_share(volume)

        self._copy_volume_from_snapshot(snapshot, volume, volume.size)
        return {'provider_location': volume.provider_location}

    def _copy_volume_from_snapshot(self, snapshot, volume, volume_size,
                                   src_encryption_key_id=None,
                                   new_encryption_key_id=None):
        """Copy snapshot to destination volume."""

        LOG.debug("snapshot: %(snap)s, volume: %(vol)s, ",
                  {'snap': snapshot.id,
                   'vol': volume.id,
                   'size': volume_size})
        info_path = self._local_path_volume_info(snapshot.volume)
        snap_info = self._read_info_file(info_path)
        vol_path = self._local_volume_dir(snapshot.volume)
        forward_file = snap_info[snapshot.id]
        forward_path = os.path.join(vol_path, forward_file)

        img_info = self._qemu_img_info(forward_path, snapshot.volume.name)
        path_to_snap_img = os.path.join(vol_path, img_info.backing_file)

        path_to_new_vol = self._local_path_volume(volume)
        if img_info.backing_file_format == 'raw':
            image_utils.convert_image(path_to_snap_img,
                                      path_to_new_vol,
                                      img_info.backing_file_format,
                                      run_as_root=self._execute_as_root)
        else:
            self._do_fast_clone_file(path_to_snap_img, path_to_new_vol)
            command = ['qemu-img', 'rebase', '-b', "", '-F',
                       img_info.backing_file_format, path_to_new_vol]
            self._execute(*command, run_as_root=self._execute_as_root)

        self._set_rw_permissions(path_to_new_vol)

    def _create_cloned_volume(self, volume, src_vref):
        """Clone src volume to destination volume."""
        LOG.debug('Cloning volume %(src)s to volume %(dst)s',
                  {'src': src_vref.id, 'dst': volume.id})

        volume_name = CONF.volume_name_template % volume.name_id

        vol_attrs = ['provider_location', 'size', 'id', 'name', 'status',
                     'volume_type', 'metadata', 'obj_context']
        Volume = collections.namedtuple('Volume', vol_attrs)
        volume_info = Volume(provider_location=src_vref.provider_location,
                             size=src_vref.size,
                             id=volume.name_id,
                             name=volume_name,
                             status=src_vref.status,
                             volume_type=src_vref.volume_type,
                             metadata=src_vref.metadata,
                             obj_context=volume.obj_context)
        src_volume_path = self._local_path_volume(src_vref)
        dst_volume = self._local_path_volume(volume_info)
        self._do_fast_clone_file(src_volume_path, dst_volume)

        if volume.size > src_vref.size:
            LOG.info('Resize the volume %s to %sG', dst_volume, volume.size)
            image_utils.resize_image(dst_volume, volume.size,
                                     run_as_root=False,
                                     file_format='raw')

        if 'admin_metadata' in src_vref and 'format' in src_vref.admin_metadata:
            volume.admin_metadata['format'] = (
                src_vref.admin_metadata['format'])
            with volume.obj_as_admin():
                volume.save()
        return {'provider_location': src_vref.provider_location}
EOF
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
