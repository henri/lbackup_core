#!/bin/bash

# Copyright and Licence Notice
#
# (C)Copyright 2008 Henri Shustak
# Licended under the GNU GPL
# Lucid Information Systems
# http://www.lucidsystems.org
#

#
# Version 0.0.2
#

# Description
#
# Mounts a remote area via SFTP 
# Desinged for backup purposes
# Requires MacFuse and SSHFS
#

#
# This script is part of the LBackup project
# LBackup Home : http://www.lucidsystems.org/lbackup
# LBackup Related Link : https://connect.homeunix.com/lbackup/doku.php?id=network_backup_strategies
#

## SSH Settings :

volume_name="backupmount"
ssh_user_name="username"
ssh_server="servername"
ssh_remote_directory="/Volumes/BigRaid/Backups"


# Mount SSHFS Settings :

mount_point="/Volumes/${volume_name}"
alternate_backup_device="/Volumes/BigDisk"


# Internal Varibles : 

SSHFS=/usr/local/bin/sshfs
mount_point_created="NO"



# Functions that check for alternative backup devices.


function backup_device_already_attached {
    exit 0
}

function check_for_local_backup_devices {
    if [ -d "$alternate_backup_device" ] ; then
        echo "    ERROR: Alternative backup device present. "
        echo "           $alternate_backup_device"
        backup_device_already_attached
    fi
}

check_for_local_backup_devices



# Mount some SFTP points mounting with FUSE!

if ! [ -d ${mount_point} ] ; then 

    # Create the mount point
    mkdir ${mount_point}
    if [ $? != 0 ] ; then
        echo "    ERROR! : Creating Mount Point" | tee -ai $logFile
        exit -1
    else
        mount_point_created="YES"
    fi
    
    # connect to the mount point using SSHFS
    $SSHFS ${ssh_user_name}@${ssh_server}:${ssh_remote_directory} ${mount_point} -oreconnect,ping_diskarb,volname=${volume_name}
    if [ $? != 0 ] ; then
        if [ "${mount_point_created}" == "YES" ] && [ -d "${mount_point}" ] ; then
            rm -R "${mount_point}"
            if [ $? != 0 ] ; then
                echo "    ERROR! : Removing Mountpoint : ${mount_point}"
            fi
        fi
        echo "    ERROR! : Mounting via SSH" | tee -ai $logFile
        exit -1 
    fi
    sleep 25
else
    echo "    ERROR! : Mount point is currenlty in use."
fi


exit 0



