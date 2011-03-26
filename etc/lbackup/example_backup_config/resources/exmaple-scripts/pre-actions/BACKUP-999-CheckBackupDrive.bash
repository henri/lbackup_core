#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##					                        	##
##	             Check Backup Drive             ##
##      	          (C)2009                   ##
##						                        ##
##		           Version 0.0.1 	            ##
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
#  This is a simple script which opens the log file
#  Note : Someone must be logged in for this script
#         to work.
#



###############################
####     CONFIGURATION      ###
###############################


# Set the backup directory
backup_directory="/Volumes/BackupDrive"



###############################
####       FUNCTIONS        ###
###############################


function check_backup_disk_availibility {

    if [ -d "${backup_directory}" ] ; then
        return 0
    else
        return -1
    fi

}


###############################
####     PERFROM ACTION     ###
###############################



check_backup_disk_availibility
if [ $? != 0 ] ; then
    exit $SCRIPT_HALT
else
    exit $SCRIPT_SUCCESS
fi



