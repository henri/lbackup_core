#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	              UNMOUNT VOLUME	  	        ##
##      		     (C)2009		            ##
##						                        ##
##		          Version 0.0.1 	            ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##        This software is licensed under 	    ##
##                  the GNU GPL.                ##
##						                        ##
##	     The developer of this software	        ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions available from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################


#
#  This is a simple script which will use the diskutil
#  to unmount the specified volume.
#
#  Keep in mind that some devices have more than one volume.
#
#  Note : This Script Requires Mac OS 10.4 or later
#


#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lucidsystems.org/lbackup
#  Related Page : https://connect.homeunix.com/lbackup/doku.php?id=network_backup_strategies
#


unmounted_volume="NO"

function unmount_volumes {



    ###############################
    ####     PERFORM ACTION     ###
    ###############################

    # Check the Volume is Mounted
    if [ -d "/Volumes/${volume_to_unmount}" ] ; then

        # Unmount the mounted volume
        echo "    Unmounting Backup Volume..." | tee -ai $logFile
        diskutil unmount "/Volumes/${volume_to_unmount}" | sed s'/^/    /' | tee -ai $logFile
        command_exit_status=$?
        if [ ${command_exit_status} != 0 ] ; then
            echo "    WARNING! : Unable to Unmount Backup Volume."| tee -ai $logFile
            exit ${SCRIPT_WARNING}
        else
            unmounted_volume="YES"
        fi

    else
        # Report that the volume was not mounted
        echo "    Backup Volume Not Mounted : ${volume_to_unmount}" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi

}



###############################
####        SETTINGS        ###
###############################

# Set this variable to the name of the mounted volume you wish to eject

# This example will only report if no volumes were found to unmount. Alter the section below to change this behavior

volume_to_unmount="Backup1"
if [ -d "/Volumes/${volume_to_unmount}" ] ; then
    unmount_volumes
fi

volume_to_unmount="Backup2"
if [ -d "/Volumes/${volume_to_unmount}" ] ; then
    unmount_volumes
fi





###############################
####        REPORTING        ###
###############################


if [ "${unmounted_volume}" == "YES" ] ; then
    exit ${SCRIPT_SUCCESS}
else
     # Report that the volume was not mounted
     echo "    WARNING! : No Backup Volumes Unmounted"| tee -ai $logFile
     exit ${SCRIPT_WARNING}
fi



