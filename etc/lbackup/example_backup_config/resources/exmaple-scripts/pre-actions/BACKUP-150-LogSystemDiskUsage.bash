#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##					                            ##
##	            CLEAR RSYNC SESSION             ##
##      	          (C)2009                   ##
##						                        ##
##		           Version 0.0.2 	            ##
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
#  This is a script will provide informaton regarding 
#  the disk usage on the system.
#




###############################
####        SETTINGS        ###
###############################

# include information on the disk usage of the source in the report (YES/NO)
report_system_diskusage="YES"
report_source_diskusage="NO"
report_destination_diskusage="YES"


###############################
####     PERFROM ACTION     ###
###############################


function log_system_disk_usage {
    
    # System Disk Usage 
    if [ "${report_system_diskusage}" == "YES" ] ; then
        df -hi | sed s'/^/        /' | tee -ai $logFile
    fi
    
    # Source Disk Usage
    if [ "${report_source_diskusage}" == "YES" ] ; then
        echo "Backup Source : ${backupSource} " | tee -ai $logFile
        if [ -d "${backupSource}" ] || [ -f "${backupSource}" ] ; then
            backup_source_disk_usage=`du -hs "${backupSource}"`
            echo "Source Disk Usage : ${backup_source_disk_usage}" | tee -ai $logFile
        fi
    fi
    
    # Destination Disk Usage
    if [ "${report_destination_diskusage}" == "YES" ] ; then
        echo "Backup Destination : ${backupDest} " | tee -ai $logFile
        if [ -d "${backupDest}/Section.0" ] ; then
            previous_backup_disk_usage=`du -hs "${backupDest}/Section.0"`
            echo "Previous Backup Disk Usage : ${previous_backup_disk_usage}" | tee -ai $logFile
        fi
    fi
    
    # You could also do something more involved such as working out how much space is required or just show the appropriate disk usage.
    
}


###############################
####         LOGIC          ###
###############################

log_system_disk_usage

exit ${SCRIPT_SUCCESS}
	
exit 0
