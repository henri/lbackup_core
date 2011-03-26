#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	       BASIC MOUNT DISK IMAGE VOLUME	    ##
##      		     (C)2005			        ##
##						                        ##
##		          Version 0.0.1 	            ##
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
# This is a basic script. There is a more advanced version of this script within the example lbackup
# configuration directory
#

###############################
####        SETTINGS        ###
###############################


# Volume containing the disk image ( no trialing slash )
backupVolume="/Volumes/BackupDrive1"

# Name of the volume once mounted ( no trailing slash )
imageVolumeName="/Volumes/backup_data_image"

# Location of the dsik image file
imageVolumeLocation="/Volumes/BackupDrive1/backupimage.sparseimage"


###############################
####     PERFROM ACTION     ###
###############################

function perform_backup {
	# Check if Image Volume is Mounted
	dfResult=`df | grep $imageVolumeName`
	if [ "$dfResult" == "" ] ; then
		# Image volume is not currently mounted, attempt to mount
		echo "    Mounting Backup Image Volume..." | tee -ai $logFile
		## Mount with verification - Good for manual backup (you can skip it manually this is a good meathod use this if possible.)
		hdiutil attach "${imageVolumeLocation}" > /dev/null
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
    echo "    Unable to Detect Backup Drive" | tee -ai $logFile
    exit ${SCRIPT_HALT}
fi

	
exit 0
