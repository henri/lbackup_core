#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin



##################################################
##						                        ##
##	         Lucid Information Systems 	        ##
##						                        ##
##      Reports Disk Usage of Backup Volume     ##
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

# This script requires LBackup 0.9.8r5 later.
#
# This script will simply report the backup destation volume
# disk usage as a percentage. Regardless of the ammount of
# disk utiliatization the backup will continue.
#
# This script is designed to work with OS X systems.
# Contributions to make this script work on other platforms is
# warmly welcomed : http://www.lbackup.org
#
# If you would like to cancel a backup should the percentage be
# to low then you should look at the example script called : 
# BACKUP-200-CheckBackupDiskUsagePercentage.bash
#


## Configuration



## Intenral Varibles

# You may wish to change this slightly if you want to check a differnet drive or an OS other than Mac OS X.
# If you are dealing with disk images altering this further may be useful. 
backupDestVolume=`echo "${backupDest}" | awk -F "/" '{ print $1"/"$2"/"$3}'`

backupDestVolume_diskusage_percentage=-1

## Preflight check
if ! [ -d "${backupDestVolume}" ]  ; then
    echo "    ERROR! : Unable to locate the backup volume. As such, unable to" | tee -ai $logFile
    echo "             calculate percentage disk usage on the backup destination volume." | tee -ai $logFile
    exit ${SCRIPT_WARNING}
fi


## Functions 
function calculate_disk_usage_for_backup_destination_volume {
    backupDestVolume_diskusage_percentage=`df -h | grep "${backupDestVolume}" | awk '{print $5}' | awk -F "%" '{print $1}'`
    if [ $? != 0 ] || ! [ $backupDestVolume_diskusage_percentage -ge 0 ] ; then
        echo "    ERROR! : Unable to calculate percentage disk usage on the backup destination volume." | tee -ai $logFile
        echo "             ${backupDestVolume}" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
}


## Logic

# work out the disk usage for the backup volume
calculate_disk_usage_for_backup_destination_volume

# report the disk utilization of the backup volume
echo "    Backup volume disk utilization is : ${backupDestVolume_diskusage_percentage}%" | tee -ai $logFile
exit ${SCRIPT_SUCCESS}








