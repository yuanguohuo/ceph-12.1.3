"""
API for CRUD lvm tag operations. Follows the Ceph LVM tag naming convention
that prefixes tags with ``ceph.`` and uses ``=`` for assignment, and provides
set of utilities for interacting with LVM.
"""
import json
from ceph_volume import process
from ceph_volume.exceptions import MultipleLVsError, MultipleVGsError


def parse_tags(lv_tags):
    """
    Return a dictionary mapping of all the tags associated with
    a Volume from the comma-separated tags coming from the LVM API

    Input look like::

       "ceph.osd_fsid=aaa-fff-bbbb,ceph.osd_id=0"

    For the above example, the expected return value would be::

        {
            "ceph.osd_fsid": "aaa-fff-bbbb",
            "ceph.osd_id": "0"
        }
    """
    if not lv_tags:
        return {}
    tag_mapping = {}
    tags = lv_tags.split(',')
    for tag_assignment in tags:
        key, value = tag_assignment.split('=', 1)
        tag_mapping[key] = value

    return tag_mapping


def get_api_vgs():
    """
    Return the list of group volumes available in the system using flags to include common
    metadata associated with them

    Command and sample JSON output, should look like::

        $ sudo vgs --reportformat=json
        {
            "report": [
                {
                    "vg": [
                        {
                            "vg_name":"VolGroup00",
                            "pv_count":"1",
                            "lv_count":"2",
                            "snap_count":"0",
                            "vg_attr":"wz--n-",
                            "vg_size":"38.97g",
                            "vg_free":"0 "},
                        {
                            "vg_name":"osd_vg",
                            "pv_count":"3",
                            "lv_count":"1",
                            "snap_count":"0",
                            "vg_attr":"wz--n-",
                            "vg_size":"32.21g",
                            "vg_free":"9.21g"
                        }
                    ]
                }
            ]
        }

    """
    stdout, stderr, returncode = process.call(
        [
            'sudo', 'vgs', '--reportformat=json'
        ]
    )
    report = json.loads(''.join(stdout))
    for report_item in report.get('report', []):
        # is it possible to get more than one item in "report" ?
        return report_item['vg']
    return []


def get_api_lvs():
    """
    Return the list of logical volumes available in the system using flags to include common
    metadata associated with them

    Command and sample JSON output, should look like::

        $ sudo lvs -o  lv_tags,lv_path,lv_name,vg_name --reportformat=json
        {
            "report": [
                {
                    "lv": [
                        {
                            "lv_tags":"",
                            "lv_path":"/dev/VolGroup00/LogVol00",
                            "lv_name":"LogVol00",
                            "vg_name":"VolGroup00"},
                        {
                            "lv_tags":"ceph.osd_fsid=aaa-fff-0000,ceph.osd_fsid=aaa-fff-bbbb,ceph.osd_id=0",
                            "lv_path":"/dev/osd_vg/OriginLV",
                            "lv_name":"OriginLV",
                            "vg_name":"osd_vg"
                        }
                    ]
                }
            ]
        }

    """
    stdout, stderr, returncode = process.call(
        ['sudo', 'lvs', '-o', 'lv_tags,lv_path,lv_name,vg_name', '--reportformat=json'])
    report = json.loads(''.join(stdout))
    for report_item in report.get('report', []):
        # is it possible to get more than one item in "report" ?
        return report_item['lv']
    return []


def get_lv(lv_name=None, vg_name=None, lv_path=None, lv_tags=None):
    """
    Return a matching lv for the current system, requiring ``lv_name``,
    ``vg_name``, ``lv_path`` or ``tags``. Raises an error if more than one lv
    is found.

    It is useful to use ``tags`` when trying to find a specific logical volume,
    but it can also lead to multiple lvs being found, since a lot of metadata
    is shared between lvs of a distinct OSD.
    """
    if not any([lv_name, vg_name, lv_path, lv_tags]):
        return None
    lvs = Volumes()
    return lvs.get(lv_name=lv_name, vg_name=vg_name, lv_path=lv_path, lv_tags=lv_tags)


def create_lv(name, group, size=None, **tags):
    """
    Create a Logical Volume in a Volume Group. Command looks like::

        lvcreate -L 50G -n gfslv vg0

    ``name``, ``group``, and ``size`` are required. Tags are optional and are "translated" to include
    the prefixes for the Ceph LVM tag API.

    """
    # XXX add CEPH_VOLUME_LVM_DEBUG to enable -vvvv on lv operations
    type_path_tag = {
        'journal': 'ceph.journal_device',
        'data': 'ceph.data_device',
        'block': 'ceph.block',
        'wal': 'ceph.wal',
        'db': 'ceph.db',
        'lockbox': 'ceph.lockbox_device',
    }
    if size:
        process.run([
            'sudo',
            'lvcreate',
            '--yes',
            '-L',
            '%sG' % size,
            '-n', name, group
        ])
    # create the lv with all the space available, this is needed because the
    # system call is different for LVM
    else:
        process.run([
            'sudo',
            'lvcreate',
            '--yes',
            '-l',
            '100%FREE',
            '-n', name, group
        ])

    lv = get_lv(lv_name=name, vg_name=group)
    ceph_tags = {}
    for k, v in tags.items():
        ceph_tags['ceph.%s' % k] = v
    lv.set_tags(ceph_tags)

    # when creating a distinct type, the caller doesn't know what the path will
    # be so this function will set it after creation using the mapping
    path_tag = type_path_tag[tags['type']]
    lv.set_tags(
        {path_tag: lv.lv_path}
    )
    return lv


def get_vg(vg_name=None, vg_tags=None):
    """
    Return a matching vg for the current system, requires ``vg_name`` or
    ``tags``. Raises an error if more than one vg is found.

    It is useful to use ``tags`` when trying to find a specific volume group,
    but it can also lead to multiple vgs being found.
    """
    if not any([vg_name, vg_tags]):
        return None
    vgs = VolumeGroups()
    return vgs.get(vg_name=vg_name, vg_tags=vg_tags)


class VolumeGroups(list):
    """
    A list of all known volume groups for the current system, with the ability
    to filter them via keyword arguments.
    """

    def __init__(self):
        self._populate()

    def _populate(self):
        # get all the vgs in the current system
        for vg_item in get_api_vgs():
            self.append(VolumeGroup(**vg_item))

    def _purge(self):
        """
        Deplete all the items in the list, used internally only so that we can
        dynamically allocate the items when filtering without the concern of
        messing up the contents
        """
        self[:] = []

    def _filter(self, vg_name=None, vg_tags=None):
        """
        The actual method that filters using a new list. Useful so that other
        methods that do not want to alter the contents of the list (e.g.
        ``self.find``) can operate safely.

        .. note:: ``vg_tags`` is not yet implemented
        """
        filtered = [i for i in self]
        if vg_name:
            filtered = [i for i in filtered if i.vg_name == vg_name]

        # at this point, `filtered` has either all the volumes in self or is an
        # actual filtered list if any filters were applied
        if vg_tags:
            tag_filtered = []
            for k, v in vg_tags.items():
                for volume in filtered:
                    if volume.tags.get(k) == str(v):
                        if volume not in tag_filtered:
                            tag_filtered.append(volume)
            # return the tag_filtered volumes here, the `filtered` list is no
            # longer useable
            return tag_filtered

        return filtered

    def filter(self, vg_name=None, vg_tags=None):
        """
        Filter out groups on top level attributes like ``vg_name`` or by
        ``vg_tags`` where a dict is required. For example, to find a Ceph group
        with dmcache as the type, the filter would look like::

            vg_tags={'ceph.type': 'dmcache'}

        .. warning:: These tags are not documented because they are currently
                     unused, but are here to maintain API consistency
        """
        if not any([vg_name, vg_tags]):
            raise TypeError('.filter() requires vg_name or vg_tags (none given)')
        # first find the filtered volumes with the values in self
        filtered_groups = self._filter(
            vg_name=vg_name,
            vg_tags=vg_tags
        )
        # then purge everything
        self._purge()
        # and add the filtered items
        self.extend(filtered_groups)

    def get(self, vg_name=None, vg_tags=None):
        """
        This is a bit expensive, since it will try to filter out all the
        matching items in the list, filter them out applying anything that was
        added and return the matching item.

        This method does *not* alter the list, and it will raise an error if
        multiple VGs are matched

        It is useful to use ``tags`` when trying to find a specific volume group,
        but it can also lead to multiple vgs being found (although unlikely)
        """
        if not any([vg_name, vg_tags]):
            return None
        vgs = self._filter(
            vg_name=vg_name,
            vg_tags=vg_tags
        )
        if not vgs:
            return None
        if len(vgs) > 1:
            # this is probably never going to happen, but it is here to keep
            # the API code consistent
            raise MultipleVGsError(vg_name)
        return vgs[0]


class Volumes(list):
    """
    A list of all known (logical) volumes for the current system, with the ability
    to filter them via keyword arguments.
    """

    def __init__(self):
        self._populate()

    def _populate(self):
        # get all the lvs in the current system
        for lv_item in get_api_lvs():
            self.append(Volume(**lv_item))

    def _purge(self):
        """
        Deplete all the items in the list, used internally only so that we can
        dynamically allocate the items when filtering without the concern of
        messing up the contents
        """
        self[:] = []

    def _filter(self, lv_name=None, vg_name=None, lv_path=None, lv_tags=None):
        """
        The actual method that filters using a new list. Useful so that other
        methods that do not want to alter the contents of the list (e.g.
        ``self.find``) can operate safely.
        """
        filtered = [i for i in self]
        if lv_name:
            filtered = [i for i in filtered if i.lv_name == lv_name]

        if vg_name:
            filtered = [i for i in filtered if i.vg_name == vg_name]

        if lv_path:
            filtered = [i for i in filtered if i.lv_path == lv_path]

        # at this point, `filtered` has either all the volumes in self or is an
        # actual filtered list if any filters were applied
        if lv_tags:
            tag_filtered = []
            for k, v in lv_tags.items():
                for volume in filtered:
                    if volume.tags.get(k) == str(v):
                        if volume not in tag_filtered:
                            tag_filtered.append(volume)
            # return the tag_filtered volumes here, the `filtered` list is no
            # longer useable
            return tag_filtered

        return filtered

    def filter(self, lv_name=None, vg_name=None, lv_path=None, lv_tags=None):
        """
        Filter out volumes on top level attributes like ``lv_name`` or by
        ``lv_tags`` where a dict is required. For example, to find a volume
        that has an OSD ID of 0, the filter would look like::

            lv_tags={'ceph.osd_id': '0'}

        """
        if not any([lv_name, vg_name, lv_path, lv_tags]):
            raise TypeError('.filter() requires lv_name, vg_name, lv_path, or tags (none given)')
        # first find the filtered volumes with the values in self
        filtered_volumes = self._filter(
            lv_name=lv_name,
            vg_name=vg_name,
            lv_path=lv_path,
            lv_tags=lv_tags
        )
        # then purge everything
        self._purge()
        # and add the filtered items
        self.extend(filtered_volumes)

    def get(self, lv_name=None, vg_name=None, lv_path=None, lv_tags=None):
        """
        This is a bit expensive, since it will try to filter out all the
        matching items in the list, filter them out applying anything that was
        added and return the matching item.

        This method does *not* alter the list, and it will raise an error if
        multiple LVs are matched

        It is useful to use ``tags`` when trying to find a specific logical volume,
        but it can also lead to multiple lvs being found, since a lot of metadata
        is shared between lvs of a distinct OSD.
        """
        if not any([lv_name, vg_name, lv_path, lv_tags]):
            return None
        lvs = self._filter(
            lv_name=lv_name,
            vg_name=vg_name,
            lv_path=lv_path,
            lv_tags=lv_tags
        )
        if not lvs:
            return None
        if len(lvs) > 1:
            raise MultipleLVsError(lv_name, lv_path)
        return lvs[0]


class VolumeGroup(object):
    """
    Represents an LVM group, with some top-level attributes like ``vg_name``
    """

    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)
        self.name = kw['vg_name']
        self.tags = parse_tags(kw.get('vg_tags', ''))

    def __str__(self):
        return '<%s>' % self.name

    def __repr__(self):
        return self.__str__()


class Volume(object):
    """
    Represents a Logical Volume from LVM, with some top-level attributes like
    ``lv_name`` and parsed tags as a dictionary of key/value pairs.
    """

    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)
        self.lv_api = kw
        self.name = kw['lv_name']
        self.tags = parse_tags(kw['lv_tags'])

    def __str__(self):
        return '<%s>' % self.lv_api['lv_path']

    def __repr__(self):
        return self.__str__()

    def set_tags(self, tags):
        """
        :param tags: A dictionary of tag names and values, like::

            {
                "ceph.osd_fsid": "aaa-fff-bbbb",
                "ceph.osd_id": "0"
            }

        At the end of all modifications, the tags are refreshed to reflect
        LVM's most current view.
        """
        for k, v in tags.items():
            self.set_tag(k, v)
        # after setting all the tags, refresh them for the current object, use the
        # lv_* identifiers to filter because those shouldn't change
        lv_object = get_lv(lv_name=self.lv_name, lv_path=self.lv_path)
        self.tags = lv_object.tags

    def set_tag(self, key, value):
        """
        Set the key/value pair as an LVM tag. Does not "refresh" the values of
        the current object for its tags. Meant to be a "fire and forget" type
        of modification.
        """
        # remove it first if it exists
        if self.tags.get(key):
            current_value = self.tags[key]
            tag = "%s=%s" % (key, current_value)
            process.call(['sudo', 'lvchange', '--deltag', tag, self.lv_api['lv_path']])

        process.call(
            [
                'sudo', 'lvchange',
                '--addtag', '%s=%s' % (key, value), self.lv_path
            ]
        )
