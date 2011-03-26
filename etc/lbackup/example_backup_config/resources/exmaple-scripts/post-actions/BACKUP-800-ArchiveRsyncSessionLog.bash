#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin


##################################################
##						                        ##
##	         Lucid Information Systems   	    ##
##						                        ##
##	       Archives the Rsync Session Log       ##
##      	         (C)2009         		    ##
##						                        ##
##		          Version 0.0.4              	##
##                                              ##
##           Developed by Henri Shustak         ##
##                                              ##
##        This software is licensed under 	    ##
##                  the GNU GPL.                ##
##					                            ##
##	   The developer of this software           ## 
##     maintains rights as specified in the     ##
##   Lucid Terms and Conditions available from  ##
##         http://www.lucidsystems.org     	    ##
##                                              ##
##################################################    


#
#  This script will copy the rsync_session_log
#  into an archvie folder with the date appended
#  to the name of the session log. 
#
#  This script will not remove the session log after
#  copying to the archive directory.
#

#
# This script requires lbackup version 0.9.8.r4 or later

#
#  This script is part of the LBackup project.
#  LBackup Home : http://www.lucidsystems.org/lbackup
#  Related Page : https://connect.homeunix.com/lbackup/example_scripts
#


###### Settings ######

# Name of the directory we where put the links
rsync_session_log_name="${rsync_session_log_name}" # default : "rsync_session.log"
log_archive_folder_name="log_archive"              # default : "log_archive"
remove_old_session_log_archives="NO"               # YES / NO - If there are more than the number of rotations set in the configuration file


###### Variables ######

rsync_session_log_exists="NO"
log_archive_folder_exits="NO"

numRotations=${numRotations}
numRotations_minus_one=${numRotations}
((numRotations_minus_one--))

rsync_session_log_absolute="${backupConfigurationFolderPath}/${rsync_session_log_name}"
log_archive_folder_absolute="${backupConfigurationFolderPath}/${log_archive_folder_name}"


###### Functions ######


function preflight_checks {

        if  [ -f ${rsync_session_log_absolute} ] ; then
                rsync_session_log_exists="YES"
        else
            echo "    WARNING! : Session log was not found. Archiving will not be possible." | tee -ai $logFile
            echo "               ${rsync_session_log_absolute}" | tee -ai $logFile
            echo "" | tee -ai $logFile
            exit ${SCRIPT_WARNING}
        fi
        
        
        if  [ -d ${log_archive_folder_absolute} ] ; then
                log_archive_folder_exits="YES"
        fi
        
        if [ "${backupConfigurationFolderPath}" == "" ] ; then
               echo "    WARNING! : backupConfigurationFolderPath variable was not set." | tee -ai $logFile
               exit ${SCRIPT_WARNING}
        fi
            
        if [ "${rsync_session_log_name}" == "" ] ; then
               echo "    WARNING! : rsync_session_log_name variable was not set." | tee -ai $logFile
               exit ${SCRIPT_WARNING}
        fi

        if ! [ -d "${backupConfigurationFolderPath}" ] ; then
               echo "    WARNING! : Backup configuration directory is not available, rsync session log archiving canceled." | tee -ai $logFile
               exit ${SCRIPT_WARNING}
        fi
        
        if [ "${backup_status}" != "SUCCESS" ] ; then
                       # You can remove this if you want the rsync log session log to be archived regardeless of the backup status.
                       echo "    WARNING! : Backup was not successful, rsync session log will not be archived." | tee -ai $logFile
                       exit ${SCRIPT_WARNING}
        fi
        
}


function generate_rsync_session_log_archive_directory {

        echo "     Generating session log archive directory..."  | tee -ai $logFile

        mkdir "${log_archive_folder_absolute}"
        if [ $? == 0 ] ; then
            echo "     Created archive directory : ${log_archive_folder_absolute}" | tee -ai $logFile
        else
            echo "     WARNING! : Unable to generate rsync session log archive directory" | tee -ai $logFile
            exit ${SCRIPT_WARNING}
        fi
        
}



function archive_rsync_session_log {
    
    current_date=`date "+%Y-%m-%d_@%H-%M-%S"`
    rsync_session_log_destination_name="rsync_session_log_${current_date}.log"
    rsync_session_log_destination_absolute="${log_archive_folder_absolute}/${rsync_session_log_destination_name}"
    
    # Check there is no file already archived
    if [ -f "${rsync_session_log_destination_absolute}" ] ; then
        echo "     WARNING! : rsync session log with name already exists in archive directory." | tee -ai $logFile
        echo "                ${rsync_session_log_destination_absolute}"  | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
    
    # Copy that log.
    cp "${rsync_session_log_absolute}" "${rsync_session_log_destination_absolute}"
    if [ $? != 0 ] ; then
        echo "     WARNING! : during copying of rsync session log into archive directory." | tee -ai $logFile
        echo "                       source file : ${log_archive_folder_absolute}" | tee -ai $logFile
        echo "                  destination file : ${rsync_session_log_destination_absolute}" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi
    
}

function remove_old_rsync_session_logs {
    
    # Check this directory actually exists
    if ! [ -d "${log_archive_folder_absolute}" ] ; then
         echo "     WARNING! : Unable to locate the rsync session log archive directory." | tee -ai $logFile
         echo "                ${log_archive_folder_absolute}" | tee -ai $logFile
         exit ${SCRIPT_WARNING}
    fi

    # list the directory by time modified and place the items into an array so we can skip past the ones we want to keep
    # If there and items left in the arry then we will be deleting these as they are outdated.
    # Yes this apparch messed up and constructive critisim / pathces are both welcome.
    rsync_session_log_array=(`ls -t "${log_archive_folder_absolute}" | grep "${rsync_session_log_name}"`)

    # Check that there are some rsync session log archives
    number_of_archived_session_logs=`echo ${#rsync_session_log_array[@]}`    
    if [ $number_of_archived_session_logs == 0 ] ; then
        echo "     NOTICE! : No archived logs located in the rsync log archive directory." | tee -ai $logFile
        echo "               ${log_archive_folder_absolute}" | tee -ai $logFile
        exit ${SCRIPT_WARNING}
    fi

    # Check to see if there are more archived rsync session logs than there are rotations in this configuation
    # The number of rotations is accruate - even though the access to the array starts at zero
    if [ ${number_of_archived_session_logs} -gt ${numRotations} ] ; then
        # Okay so we need to remove some of these archives 

        # Lets calculate some indexes first to work out between which two points we are removing items.
        number_of_archived_session_logs_minus_one=${number_of_archived_session_logs}
        ((number_of_archived_session_logs_minus_one--))

        current_removal_point_in_array=${numRotations}
        end_removal_point_in_array=${number_of_archived_session_logs_minus_one}

        while [ ${current_removal_point_in_array} -le ${end_removal_point_in_array} ]; do

            rsync_session_log_filename_to_remove="${rsync_session_log_array[${current_removal_point_in_array}]}"
            rsync_session_log_absolute_path_to_file_to_remove="${log_archive_folder_absolute}/${rsync_session_log_filename_to_remove}"
            
            if [ -f "${rsync_session_log_absolute_path_to_file_to_remove}" ] ; then
                  #echo "rsync_session_log_absolute_path_to_file_to_remove : ${rsync_session_log_absolute_path_to_file_to_remove}" | tee -ai $logFile
                  rm -f "${rsync_session_log_absolute_path_to_file_to_remove}"
                  if [ $? != 0 ] ; then
                       echo "     WARNING! : Unable to delete outdated rsync log archive." | tee -ai $logFile
                       echo "                ${rsync_session_log_absolute_path_to_file_to_remove}" | tee -ai $logFile
                       exit ${SCRIPT_WARNING}
                  fi
            fi
            ((current_removal_point_in_array++))
        done
        
    fi
}


###### LOGIC ######


preflight_checks

if ! [ "${log_archive_folder_exits}" == "YES"  ] ; then
        generate_rsync_session_log_archive_directory
fi


archive_rsync_session_log
if [ "${remove_old_session_log_archives}" == "YES" ] ; then
    remove_old_rsync_session_logs
fi


exit ${SCRIPT_SUCCESS}




