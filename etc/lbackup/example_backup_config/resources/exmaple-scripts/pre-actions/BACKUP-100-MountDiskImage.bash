#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	          MOUNT DISK IMAGE VOLUME		    ##
##      		      (C)2005			        ##
##						                        ##
##		          Version 0.0.3 	            ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##       This software is licenced under 	    ##
##                  the GNU GPL.                ##
##                                              ##
##	     The developer of this software	        ## 
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions available from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################    


#
#  This is a script which mounts a disk image volume 
#
#  Note : If you are using rotating backups then make
#         sure you set the permissions on the image
#         the default to ignore permissions.
#         If you fail to set the permissions correctly
#         The backup will not work correctly.
#         This also applies to any backup volume
#
#         Some Calls in this script require that a user
#         is logged currently logged in. If no one is
#         logged in, then this script may behaive
#         unexpectedly.
#

#
# This script is part of the LBackup project
# LBackup Home Page : http://www.lucidsystems.org/lbackup
# LBackup Related Page : https://connect.homeunix.com/lbackup/doku.php?id=network_backup_strategies
#

###############################
####        SETTINGS        ###
###############################


# Volume containing the disk image ( no trialing slash )
backupVolume="/Volumes/BackupDrive1"
backupVolume2="/Volumes/BackupDrive2"
backupVolume3="/Volumes/BackupDrive3"
backupVolume4="/Volumes/BackupDrive4"


# Name of the volume once mounted ( no trailing slash )
imageVolumeName="/Volumes/backup_data_image"

# Location of the dsik image file
imageVolumeLocation="/Volumes/BackupDrive1/backupimage.sparseimage"
imageVolumeLocation2="/Volumes/BackupDrive2/backupimage.sparseimage"
imageVolumeLocation3="/Volumes/BackupDrive3/backupimage.sparseimage"
imageVolumeLocation4="/Volumes/BackupDrive4/backupimage.sparseimage"


# Mount image as 
user2mount=myusername





###############################
####     PERFROM ACTION     ###
###############################

function perform_backup {
	# Check if Image Volume is Mounted
	dfResult=`df | grep $imageVolumeName`
	if [ "$dfResult" == "" ] ; then
		# Image volume is not currently mounted, attempt to mount
		echo "    Mounting Backup Image Volume..." | tee -ai $logFile
		
		# Mount the disk image
		
		## Mount with verification - Good for manual backup (you can skip it manually this is a good meathod use this if possible.)
		su -l ${user2mount} -c "open ${imageVolumeLocation}"
        
                ## Mount with no verification (faster backup start for images residing on network - may have issues on 10.6.x and greater)
                #su -l ${user2mount} -c "hdiutil attach ${imageVolumeLocation} -noverify"
		
		
		sleep 30
		dfResult=`df | grep $imageVolumeName`
	fi

    # Check a Image Volume is Mounted for a Second Time
	if [ "$dfResult" != "" ] ; then 
		echo "    Backup Image Volume Available" | tee -ai $logFile

		# Exit and Continue With Other Scripts
		exit ${SCRIPT_SUCCESS}
		
	else
	    # Report that Backup Image Volume is Unavialible and that backup should be aborted.
		echo "    Unable to Mount Encrypted Volume" | tee -ai $logFile
		exit ${SCRIPT_HALT}
		
	fi

}



# Check backupVolume is availible
dfResult=`df | grep $backupVolume`

if [ "$dfResult" != "" ] ; then 
	echo "    Backup Volume Available" | tee -ai $logFile
	perform_backup
else 
    echo "    Unable to Detect Primary Backup Drive" | tee -ai $logFile
    backupVolume="${backupVolume2}"
    # Check backupVolume is availible
    dfResult=`df | grep $backupVolume`
    if [ "$dfResult" != "" ] ; then 
        echo "    Secondary Backup Volume Available" | tee -ai $logFile
        imageVolumeLocation="${imageVolumeLocation2}"
        perform_backup
    else
        echo "    Unable to Detect Secondary Backup Drive" | tee -ai $logFile
        backupVolume="${backupVolume3}"
        # Check backupVolume is availible
        dfResult=`df | grep $backupVolume`
        if [ "$dfResult" != "" ] ; then 
            echo "    Tertiary Backup Volume Available" | tee -ai $logFile
            imageVolumeLocation="${imageVolumeLocation3}"
            perform_backup
        else
            echo "    Unable to Detect Tertiary Backup Drive" | tee -ai $logFile
            # Check backupVolume is availible
            backupVolume="${backupVolume4}"
            dfResult=`df | grep $backupVolume`
            if [ "$dfResult" != "" ] ; then 
                echo "    Quaternary Backup Volume Available" | tee -ai $logFile
                imageVolumeLocation="${imageVolumeLocation4}"
                perform_backup
            else 
                echo "    Unable to Detect Quaternary Backup Drive" | tee -ai $logFile
                exit ${SCRIPT_HALT}
            fi    
        fi
    fi
fi
	


# Quinary = 5
# Quaternary = 4	
	
	
exit 0
