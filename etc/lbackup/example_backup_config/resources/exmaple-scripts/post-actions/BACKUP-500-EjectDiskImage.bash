#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	          EJECT DISK IMAGE VOLUME		    ##
##      		     (C)2005		            ##
##						                        ##
##		          Version 0.0.6 	            ##
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
#  This is a simple script which will use the finder 
#  to eject the specified disk. This script requires
#  applescript and will also require a user to be 
#  logged in, as it is making a call using appplescript
#  to preform the unmount.
#  
#  Note : This Script Requires Mac OS 10.4 or later
#


#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lbackup.org
#  Related Page : https://www.lbackup.org/network_backup_strategies
#


exit_value=${SCRIPT_SUCCESS}

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
    
        # Eject the mounted volume
        echo "    Ejecting Backup Disk Image..." | tee -ai $logFile
        osascript -e "${apple_script_command}" | tee -ai $logFile
        apple_script_exit=$?
        if [ ${apple_script_exit} != ${SCRIPT_SUCCESS} ] ; then
            exit ${apple_script_exit}
        fi
        
        # Check the volume was ejected
        sleep 5
        if [ -d "/Volumes/${volume_to_unmount}" ] ; then 
            echo "    Unable to Eject Backup Volume : /Volumes/${volume_to_unmount}" | tee -ai $logFile
            exit_value=${SCRIPT_WARNING}
            # Uncomment line below to prevent other disks from being ejected.
            #exit ${SCRIPT_WARNING}
        else
            echo "    Volume Ejected : /Volumes/${volume_to_unmount}" | tee -ai $logFile
        fi
        
    else
        
        if [ "${volume_to_unmount}" != "$ssh_mountpoint" ] ; then
            # Report that the volume was not mounted
            echo "    Backup Volume Not Mounted : Unable to Eject : ${volume_to_unmount}" | tee -ai $logFile
            exit ${SCRIPT_WARNING}
        fi
    
    fi

}



###############################
####        SETTINGS        ###
###############################

# Set this variable to the name of the mounted volume you wish to eject

# Unmount the backup disk image
volume_to_unmount="backup_mount"
unmount_volumes

sleep 15

#sleep 15

#ssh_mountpoint="backup_mount_ssh" # Only applies to the SSH mountpoint
#volume_to_unmount="$ssh_mountpoint" 
#unmount_volumes


exit ${exit_value}



