#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	     	##
##						                        ##
##	          CHECK FILE IS NOT PRESENT         ##
##      		      (C)2008			        ##
##						                        ##
##		          Version 0.0.1 	            ##
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
#  This is a simple script which checks for that a file is
#  not present. If the file exists then the backup will be stopped.
#  If the file is not detectd then the backup will continue.
#



###############################
####     CONFIGURATION      ###
###############################


# Set the backup directory
file_to_check="/etc/lbackup/yourbackup/backup_in_progress.lock"



###############################
####       FUNCTIONS        ###
###############################


function check_if_file_exists {

    if [ -f "${file_to_check}" ] ; then
        exit $SCRIPT_HALT
    else
        exit $SCRIPT_SUCCESS
    fi

}


###############################
####     PERFROM ACTION     ###
###############################



check_if_file_exists








