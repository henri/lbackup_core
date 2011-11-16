#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


######################################################
##                                                  ##
##              Lucid Information Systems           ##
##                                                  ##
##            Report Disk Usage Difference          ##
##                      (C)2009                     ##
##                                                  ##
##                   Version 0.0.2                  ##
##                                                  ##
##            Developed by Henri Shustak            ##
##                                                  ##
##          This software is licensed under         ##
##                    the GNU GPL.                  ##
##                                                  ##
##            The developer of this software        ##
##        maintains rights as specified in the      ##
##     Lucid Terms and Conditions availible from    ##
##               www.lucidsystems.org               ##
##                                                  ##
##           Part of the LBackup project            ##
##              http://www.lbackup.org              ##
##                                                  ##
######################################################


#
#  If the backup was successfull then the differnece
#  in disk usage between this most recent backup and
#  the previous backup will be reported in megabytes
#  
#
#
# This script requires lbackup version 0.9.8.r2 or later

#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lbackup.org
#  Related Page : https://www.lbackup.org/example_scripts
#
# This example script utilzies the 'bc' and 'du' commands for various calculations
# This script will not work correctly if the 'bc' or the 'du' commands are not availible
#
# Next revision of this script will add options for reporting the differences by 
# the backup log files for details reported by LBackup. This information may
# be different from the actual disk utilization as reported by the 'du' command.

###### Variables ######

# output configuration varibles
report_the_backup_size_of_first_the_most_recent_snapshot="NO"


# intenral varibles
backup_set_directory="${backupDest}"
first_most_recent_backup_snapshot_path_path="${backup_set_directory}/Section.0"
first_most_recent_backup_snapshot_disk_usage=0
second_most_recent_backup_snapshot_path_path="${backup_set_directory}/Section.1"
second_most_recent_backup_snapshot_disk_usage=0
first_most_recent_exits="NO"
second_most_recent_exits="NO"
backup_set_directory_exists="NO"
directory_for_disk_usage_calculation_path_path=""
directory_fir_disk_usage_calculation_size=0
difference_between_snapshots=0
backup_snapshots_same_size=0 # 0 means they are different, 1 means they are the same
positive_difference=0 # 0 means negitive, 1 means a positive difference

###### Functions ######


function preflight_checks {

    # Check the backup set exits
    if [ -d "${backup_set_directory}" ] ; then
        backup_set_directory_exists="YES"
       
        # Check to see if there most recent backup exists
        if [ -d "${first_most_recent_backup_snapshot_path}" ] ; then
            first_most_recent_exits="YES"
        fi
        
        # Check to see if there most recent backup exists
        if [ -d "${second_most_recent_backup_snapshot_path}" ] ; then
            second_most_recent_exits="YES"
        fi
        
    else
        # Just report the fact and carry on with any other enabled the post action scripts
        echo "    WARNING! : Unable to calculate the size of the backup." | tee -ai $logFile
        echo "               Backup destination directory was not available : " | tee -ai $logFile
        echo "               ${new_link_destination}" | tee -ai $logFile
        exit ${SCRIPT_WARNING} 
    fi
    
}


function calculate_snapshot_size_in_megabytes {
    
    if [ -e "${directory_for_disk_usage_calculation_path}" ] ; then
        kilobytes_used=`du -sk "${directory_for_disk_usage_calculation_path}" | awk '{print $1}'`
        # change the way we report depending upon if the total is more or less than 10MB in total
        if [ $kilobytes_used -lt $((1024 * 10 )) ] ; then
            # report as two decimal place result (less than 10MB)
            megabytes_used=`echo "scale=2; ${kilobytes_used} / 1024" | bc | sed 's/^/0/'`
        else
            # report without any decimal precession (more than or equal to 10MB)
            megabytes_used=`echo "scale=0; ${kilobytes_used} / 1024" | bc`
        fi
    else
        # Just report the fact and carry on with any other enabled the post action scripts
        echo "    WARNING! : Unable to calculate the size of the one or more snapshots." | tee -ai $logFile
        echo "               The following directory is no longer accessible for some reason : ." | tee -ai $logFile
        echo "               $directory_for_disk_usage_calculation_path" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
    
    # Not able to return floting point numbers. Therefore setting this varible is important. Better ideas for doin this in BASH are welcome.
    directory_for_disk_usage_calculation_size="$megabytes_used"

}

function calculate_differnece_in_snapshot_size_in_megabytes {
    
    difference_between_snapshots=`echo "${first_most_recent_backup_snapshot_disk_usage} - ${second_most_recent_backup_snapshot_disk_usage}" | bc`
    positive_difference=`echo "${difference_between_snapshots} > 0" | bc`
    backup_snapshots_same_size=`echo "${first_most_recent_backup_snapshot_disk_usage} == ${second_most_recent_backup_snapshot_disk_usage}" | bc`
    difference_between_snapshots_multiplied_by_negitive_one=`echo "${difference_between_snapshots} * -1" | bc`
    
}



###### LOGIC ######

preflight_checks

# Caclulate disk usage for most recent backup
directory_for_disk_usage_calculation_path="${first_most_recent_backup_snapshot_path_path}"
calculate_snapshot_size_in_megabytes
first_most_recent_backup_snapshot_disk_usage="${directory_for_disk_usage_calculation_size}"

# Caclulate disk usage for most the next most recent backup
directory_for_disk_usage_calculation_path="${second_most_recent_backup_snapshot_path_path}"
calculate_snapshot_size_in_megabytes
second_most_recent_backup_snapshot_disk_usage="${directory_for_disk_usage_calculation_size}"

# Calculate the difference in MB between these two backups
calculate_differnece_in_snapshot_size_in_megabytes

## Reporting

# report the size of the most recent backup
if [ "${report_the_backup_size_of_first_the_most_recent_snapshot}" == "YES" ] ; then
    # report back regarding the disk utilization of the most recent backup
    echo "    This most recent snapshot consumes approximately $first_most_recent_backup_snapshot_disk_usage MB of disk space (excluding hard linking)."| tee -ai $logFile
fi

# report in english the difference in size between the most recent backup and the previous backup
if [ ${backup_snapshots_same_size} == 1 ] ; then
    echo "    The previous and the most recently completed snapshots share approximately the same disk utilization."
else
    if [ $positive_difference == 1 ] ; then 
        echo "    Compared with the previous snapshot approximately ${difference_between_snapshots} MB of additional disk usage was required." | tee -ai $logFile
    else
        echo "    This snapshot disk usage is approximately ${difference_between_snapshots_multiplied_by_negitive_one} MB smaller than the previous backup." | tee -ai $logFile
    fi
fi


exit ${SCRIPT_SUCCESS}



