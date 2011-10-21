#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	             START THE BACKUP   		    ##
##      		      (C)2005 			        ##
##						                        ##
##		          Version 0.0.2 	            ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##        This software is licenced under 	    ##
##      the GNU GPL. This software may only  	##
##            be used or installed or 		    ##
##          distributed in accordance       	##
##              with this licence.              ##
##                                              ##
##           Lucid Inormatin Systems.           ##
##						                        ##
##	     The developer of this software	        ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################


#
#
#  This Script Simply Starts the Backup, from the command line
#  Even if you are not an administrator, it will prompt for
#  administrator privilige elveation.
#
#
#  Note : This Script Requires Mac OS 10.4 or later
#

###############################
####        SETTINGS        ###
###############################

# Set this varible to the name of the mounted volume you wish to eject
path_to_log_file="/Users/henri/bin/helpdesk2_backup/DailyBackup1.log"
path_to_backup_application="/usr/local/sbin/lbackup"
path_to_backup_script="/Users/henri/bin/helpdesk2_backup/resources/exmaple-scripts/additional-scripts/start_backup/backup.bash"


################################
####    INTERNAL VARIBLES    ###
################################

# Set the apple script command - this provides root privileges, if required.
apple_script_command="return do shell script \"sudo ${path_to_backup_application} ${path_to_backup_script}\" with administrator privileges"


###############################
####     PERFROM ACTION     ###
###############################

# Check the Volume is Mounted
if [ -f "${path_to_backup_application}" ] && [ -f "${path_to_backup_script}" ]; then

    # Open Log File
    if [ "${path_to_log_file}" != "" ] ; then
        open "${path_to_log_file}"
    fi

    # Start the Backup
    echo "`date`   :   Starting Backup..."

    if [ "`whoami`" != "root" ] ; then
        osascript -e "${apple_script_command}"
    else
        ${path_to_backup_application} ${path_to_backup_script}
    fi

else

    # Report Error
    echo "ERROR! : Unable to Find Backup Script or Backup Configuration"

fi

exit 0
