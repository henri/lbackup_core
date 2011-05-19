#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin



##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##						                        ##
##  Ensure Disk Usage is Bleow a Set Percentage ##
##      	         (C)2008                    ##
##						                        ##
##	              Version 0.0.3 	            ##
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

# This script requires LBackup 0.9.8r5 later.
#
# This script will stop the backup if the destiantion volume
# has more than a certian disk usage percentage.
#
# This script is designed to work with OS X systems.
# Contributions to make this script work on other platforms is
# welcome : http://www.lbackup.org 


## Configuration

# If the disk usage percentage of the backup destiation is at this ammount or higher
# then the backup will be stoped, provided everything with finding the current disk usage takes palce.
stop_backup_if_disk_usage_is_at_or_above=80

# Report the disk utilization of the backup disk? (YES/NO)
report_disk_utilization_of_the_backup_volume="YES"


## Intenral Varibles

# You may wish to change this slightly if you want to check a differnet drive or an OS other than Mac OS X.
# If you are dealing with disk images altering this further may be useful. 
backupDestVolume=`echo "${backupDest}" | awk -F "/" '{ print $1"/"$2"/"$3}'`

backupDestVolume_diskusage_percentage=0

## Preflight check
if ! [ -d "${backupDestVolume}" ]  ; then
    echo "    ERROR! : Unable to locate the backup volume. As such, unable to" | tee -ai $logFile
    echo "             calculate percentage disk usage on the backup destination volume." | tee -ai $logFile
    exit ${SCRIPT_HALT}
fi


## Functions 
function calculate_disk_usage_for_backup_destination_volume {
    backupDestVolume_diskusage_percentage=`df -h | grep "${backupDestVolume}" | awk '{print $5}' | awk -F "%" '{print $1}'`
    if [ $? != 0 ] ; then
        echo "    ERROR! : Unable to calculate percentage disk usage on the backup destination volume." | tee -ai $logFile
        echo "             ${backupDestVolume}" | tee -ai $logFile
        exit ${SCRIPT_HALT}
    fi
}


## Logic

# work out the disk usage for the backup volume
calculate_disk_usage_for_backup_destination_volume

# return approriate value based upon the disk utilization of the backup volume
if [ ${backupDestVolume_diskusage_percentage} -ge $stop_backup_if_disk_usage_is_at_or_above ] ; then
     echo ""
     echo "    ERROR! : Disk usage on the backup destination volume is too high." | tee -ai $logFile
     echo "             Backup volume disk utilization is : ${backupDestVolume_diskusage_percentage}%" | tee -ai $logFile
     echo ""
     exit ${SCRIPT_HALT}
else
    if [ "${report_disk_utilization_of_the_backup_volume}" == "YES" ] ; then
        echo "    Backup volume disk utilization is : ${backupDestVolume_diskusage_percentage}%" | tee -ai $logFile
    fi
    exit ${SCRIPT_SUCCESS}
fi







