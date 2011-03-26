#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin



##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##						                        ##
##	       Ensure Failed Backup Writable        ##
##      	         (C)2008                    ##
##						                        ##
##	              Version 0.0.1 	            ##
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
##	      The developer of this software	    ## 
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions availible from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################     




###############################
####     PERFROM ACTION     ###
###############################

# Check that the old backup is availible


failed_backup_section=${backupDest}/Section.inprogress

if [ -d "${failed_backup_section}" ] ; then
	chmod -R +w "${failed_backup_section}"
	if [ $? != 0 ] ; then
		exit ${SCRIPT_HALT}
	fi
fi

exit ${SCRIPT_SUCCESS}		


