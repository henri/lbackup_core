#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

# this script will mount based on UUID if your system supports the following you will be presented with a list of UUIDs.
# ls -l /dev/disk/by-uuid/
#
# alterativly if you have lsblk installed on your system : 
# lsblk -o NAME,TYPE,FSTYPE,UUID,MOUNTPOINT

mount_path="/mnt/mount-path"
mount_uuid="17c1210c-8a88-42d6-b394-03f491415d5c"

exit_value=${SCRIPT_SUCCESS}

# make sure mount path exits
if ! [ -d ${mount_path} ] ; then
    /usr/bin/mkdir ${mount_path}
    if [ $? != 0 ] ; then
        exit ${SCRIPT_WARNING}
    fi
fi

# mount all drives from /etc/fstab
# /usr/bin/mount -a

/usr/bin/mountpoint ${mount_path} > /dev/null
if [ $? != 0 ] ; then
    # not mounted so mount the mount point
    /usr/bin/mount -t ext4 UUID="${mount_uuid}" ${mount_path}
    if [ $? != 0 ] ; then
        # note : exit value from mount with 32 means is already mounted
        exit_value=${SCRIPT_WARNING}
    fi
fi

exit ${exit_value}
