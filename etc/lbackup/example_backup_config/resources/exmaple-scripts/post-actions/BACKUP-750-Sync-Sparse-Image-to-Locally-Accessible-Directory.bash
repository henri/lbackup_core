#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

# Copyright 2011 Henri Shustak
# Released Under The GNU GPL v3
# Lucid Information Systems 
# http://www.lucidsystems.org

# This script will use rsync to push an updated copy of a sparse bundle image
# from the local machine to a remote machine which is accessible from a network mount.
# It is also possible to use this script to keep an additional copy of your sparse bundle 
# on the local system in sync.

## Various settings which you will want to alter before running this script.
local_sparse_bundle_to_sync="/path/to/my_backup.sparsebundle"
local_sparse_bundle_destination_dir="/path/to/destination/bundle/dir/"
path_to_rsync="/usr/local/bin/rsync_v3.0.7"

# intenral varibles just leave alone
rsync_command=""
hdiutil_mounted_status=""
local_system_kind=""

# Preflight Checks 
if [ "${backup_status}" != "SUCCESS" ] ; then
    echo "    WARNING! : Sparse image synchronization will not continue because the backup has not succeeded." | tee -ai $logFile
    exit ${SCRIPT_WARNING}
fi

# More Internal Checks and varibles
hdiutil_mounted_status=`hdiutil info | grep "image-path" | grep "${local_sparse_bundle_to_sync}"`
local_system_kind=`uname`

# Check this system is Mac OS X and that the destination is availible.
if [ "${local_system_kind}" == "Darwin" ] ; then
    # Test backup destination directory is availible
    if ! [ -d "${local_sparse_bundle_destination_dir}" ] ; then 
        echo "    WARNING! : The sparse bundle destination directory is not available."  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
else
    # Depending how critical this is you may want to halt rather than just warn.
    echo "    WARNING! : This system is not running Darwin."  | tee -ai $logFile
    exit ${SCRIPT_WARNING}
fi

# Okay now we have all the configuration information lets copy / update the sparse bundle.

# Check the image available and is not mounted.
if [ -d "${local_sparse_bundle_to_sync}" ] && [ "${hdiutil_mounted_status}" == "" ] ; then 
    # Use rsync to copy / update the remote file
    echo "    Syncing the sparse bundle image..." | tee -ai $logFile
    ${path_to_rsync} -aNHAXEx --delete --protect-args --fileflags --force-change "${local_sparse_bundle_to_sync}" "${local_sparse_bundle_destination_dir}" 2>&1 | sed s'/^/    /' | tee -ai ${logFile}
    rsync_return_value=$?
    if [ $rsync_return_value != $? ] ; then
        echo "    ERROR! : Occurred during disk image sync." | tee -ai $logFile
        echo "             Rsync Exit Value : $rsync_return_value" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    else
        echo "    Sparse bundle synchronized." | tee -ai $logFile
    fi
else
    if ! [ -d "${local_sparse_bundle_to_sync}" ] ; then
        # Source image is not availible or is still mounted.
        echo "    ERROR! : Source sparse bundle is not available : ${local_sparse_bundle_to_sync}"  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    else
        echo "    ERROR! : The source sparse bundle is mounted : ${hdiutil_mounted_status}"  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
fi

exit ${SCRIPT_SUCCESS}

