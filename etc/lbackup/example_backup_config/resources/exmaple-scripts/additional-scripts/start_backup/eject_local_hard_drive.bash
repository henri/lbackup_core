#!/bin/bash


# (C)2011, Henri Shustak, All rights reserved.
# Released under the GNU GPL v3 or later
# Part of the LBackup project : http://www.lbackup.org
#
# This script is a starting point for you to quickly stop a backup which may be taking place on your system to a spcific drive and then eject the drive.
# Great if you need to stop the backup quickly and unmount various drives which are related to the backup.

# Version History : 
#     1.0 : Initial release

# backup volume detection and backup
backup_destination_volume="/Volumes/mybackup_volume/backupdirectory/"
backup_destiation_name="mybackup_volume"

# See below and edit if you would like other drives to be unmounted.

# Intenral Varibles

logFile=/dev/null
error_unmounting="NO"
ssh_mountpoint=""

function unmount_volumes {
    
    
    ################################
    ####    INTERNAL VARIABLES    ###
    ################################
    
    # Set the apple script command
    apple_script_command='tell application "Finder" to eject disk "'${volume_to_unmount}'"'
    
    
    ###############################
    ####     PERFORM ACTION     ###
    ###############################
    
    # Check the Volume is Mounted
    if [ -d "/Volumes/${volume_to_unmount}" ] ; then 

        osascript -e "${apple_script_command}" | tee -ai $logFile
        apple_script_exit=$?
        if [ ${apple_script_exit} != 0 ] ; then
            exit ${apple_script_exit}
        fi
        
    else
        
        if [ "${volume_to_unmount}" != "$ssh_mountpoint" ] ; then
            # Report that the volume was not mounted
            echo "    Volume Not Mounted : Unable to Eject : ${volume_to_unmount}" | tee -ai $logFile
            error_unmounting="YES"
            exit -1
        fi
    
    fi

}



###############################
####        SETTINGS        ###
###############################

# Set this variable to the name of the mounted volume you wish to eject



# Check if LBackup is running : 

rsync_pid=`ps -A | grep "rsync" | grep "${backup_destination_volume}" | head -n 1 | awk '{print $1}'`
if [ "${rsync_pid}" != "" ] ; then
    # Stop the backup as it is most likley running
    echo "LBackup (using rsync) appears to be using this drive please enter you admin details to stop the backup."
    osascript -e "do shell script \"kill -15 ${rsync_pid}\" with administrator privileges"
    if [ $? != 0 ] ; then
        echo "ERROR! : Unable to stop the backup which is using the drive."
        exit -1
    fi
    sleep 5
    
    # Unmount the helpdesk2 backup disk image
    volume_to_unmount="${backup_destiation_name}"
    unmount_volumes
    
fi


# Eject Local Drives - now that LBackup is not using any
if [ `ls -l /Volumes/ | grep -v PGP_Disk | wc | awk '{print $1}'` -ge 3 ] ; then
    echo "    Ejecting Local Disks..." | tee -ai $logFile

    # Unmount the backup disk image
	# uncomment and edit as required
    
    #volume_to_unmount="VolumeNameToEject1"
    #unmount_volumes
    
    #volume_to_unmount="VolumeNameToEject4"
    #unmount_volumes

    #volume_to_unmount="VolumeNameToEject3"
    #unmount_volumes

	#.....etc......

    
else 
    echo "    No directly attached volumes found to eject." | tee -ai $logFile
fi

if [ "${error_unmounting}" == "YES" ] ; then
    echo "The \"lsof\" will help you track down what is happening."
fi


# You may need to edit this number depending upon your requirements.
if [ `ls -l /Volumes/ | wc | awk '{print $1}'` -ge 3 ] ; then
    echo "    Currently mounted volumes : "
    ls -l /Volumes/
    exit -1
else
    echo "    All volumes ejected."  
    exit 0
fi


exit 0

