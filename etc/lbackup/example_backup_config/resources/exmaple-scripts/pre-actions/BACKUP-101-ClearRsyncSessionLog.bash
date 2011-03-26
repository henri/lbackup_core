#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##					                            ##
##	            CLEAR RSYNC SESSION             ##
##      	          (C)2009                   ##
##						                        ##
##		           Version 0.0.1 	            ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##       This software is licensed under 	    ##
##                  the GNU GPL.                ##
##                                              ##
##	     The developer of this software	        ## 
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions available from  ##
##            www.lucidsystems.org     		    ##
##                                              ##
##################################################    


#
#  This is a script will erase any existing rsync
#  session log. This log contains output from rsync
#  such as the files which have been copied and 
#  also includes statistics.
#




###############################
####        SETTINGS        ###
###############################






###############################
####     PERFROM ACTION     ###
###############################


function clear_rsync_session_log {
        
        # Checks if the varible has been loaded, this will let us know if it is currently enabled.
        if [ "${rsync_session_log_file}" != "" ] ; then
                
                # Cheeks if the referenced file exists in the file system
                if [ -e "${rsync_session_log_file}" ] ; then
                
                        # Removes the old log file
                        rm -f "${rsync_session_log_file}"
                        
                        # If there were any issues removing the rsync session log file then report the error and stop the backup.
                        if [ $? != 0 ] ; then        
                                echo "ERROR! : Unable to remove the file ${rsync_session_log_file}" | tee -ai $logFile
                                exit ${SCRIPT_HALT}
                        fi
                        
                fi
                
        fi

}


###############################
####         LOGIC          ###
###############################

clear_rsync_session_log

exit ${SCRIPT_SUCCESS}
	
exit 0
