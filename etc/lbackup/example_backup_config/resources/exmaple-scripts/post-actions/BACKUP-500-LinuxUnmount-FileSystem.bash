#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

unmount_path="/mnt/drive_name"

exit_value=${SCRIPT_SUCCESS}

if [ -d ${unmount_path} ] ; then
    /usr/bin/umount ${unmount_path}
    if [ $? != 0 ] ; then
        exit_value=${SCRIPT_WARNING}
    fi
fi

exit ${exit_value}
