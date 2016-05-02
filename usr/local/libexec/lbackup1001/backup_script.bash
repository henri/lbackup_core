#!/bin/bash
PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin

##################################################
##                                              ##
##          Lucid Information Systems           ##
##                                              ##
##              LOCAL BACKUP SCRIPT             ##
##                    (C)2005                   ##
##                                              ##
##                Version 0.9.8r5               ##
##               Alpha Release 018              ##
##                                              ##
##          Developed by Henri Shustak          ##
##                                              ##
##        This software is licensed under       ##
##      the GNU GPL. This software may only     ##
##            be used or installed or           ##
##          distributed in accordance           ##
##              with this license.              ##
##                                              ##
##           Lucid Information Systems.         ##
##                                              ##
##	     The developer of this software         ##
##    maintains rights as specified in the      ##
##   Lucid Terms and Conditions available from  ##
##            www.lucidsystems.org              ##
##                                              ##
##################################################


##
## Running this script will perform a 
## backup as specified in the configuration file
## 
## It is important that you have a copy of Rsync
## installed which will preserve the meta data
## which you are planning to save
##
## Any patches should be submitted to 
## http://wwww.lucidsystems.org
## 
## Git push requests may also be sent via GitHub
## http://www.lbackup.org/source
##
## LBackup Official Home Page is
## http://www.lbackup.org
##


##################################
##      Structural Overview     ##
##################################                
#
#   You should only need to set
#   the primary configuration
#   for this subsystem to work.
#
#   The primary configuration
#   is performed in a separate configuration
#   file. The path of this configuration file
#   should be passed in as $1
#
#   There is an example configuration file
#   included called 'example_backup.conf'
#
#
#   Required Utilities : wake.py, checklog.py, growlout
#   Lucid Backup Components : maillog_script.bash
#   Dependencies : python, ssh, bash, echo, mv, rm, tee, dirname, bc, rsync or RSyncX
#
    

## Calculate amount of changed data
## Atomic Version


##################################
##         Initial Check        ##
##################################
# Backup Using  ($1) 
# Make sure a file has been passed in on the command line
if [ $# -ne 1 ]; then
         echo 1>&2 Usage: /usr/local/sbin/lbackup configuration_file.conf
         echo 1>&2        Further information is availible online http://www.lbackup.org
         exit -127
fi
 
 
 
########################
## Internal Functions ##
########################      

# Intenral Function Retrun Vlaues

# Used when you want to convert seconds into human readable output
return_value_from_make_seconds_human_readable=""

# Function is used by get_absolute_path function

# These functions need to be cleaned up

# Called by the get_absolute_path function
function resolve_symlinks {
    # Check if it is an alias
    if [ -L "$quoted_absolute_path" ] ; then 
      #  # If Alias then find where the alias is pointing
        quoted_absolute_path=`ls -l "$quoted_absolute_path" | awk 'BEGIN { FS = " -> " } ; { print $2 }'`
        n_links_followed=$[$n_links_followed+1]
        if [ $n_links_followed -gt 99 ] ; then
            echo " ERROR! : Unable to resolve link : $quoted_path2find" | tee -ai $logFile
            echo "          The symbolic links may be causing a loop." | tee -ai $logFile
            quoted_absolute_path=-30
        fi
      resolve_symlinks
    fi
}


# Before calling this function set the variable quoted_absolute_path 
# to the best guess of the absolute path. eg: quoted_absolute_path="$0"
# Upon error : quoted_absolute_path is set to -30
# You should check for this instance a loop has occurred with the links
function get_absolute_path {
    # Find the configuration files absolute path
    
    # check for ./ at the start
    local dot_slash_test=`echo "$quoted_absolute_path" | grep '^./'`
    if [ "$dot_slash_test" != "" ]  ; then
		# This is a little overkill. However, it should do the trick.
        quoted_absolute_path="`pwd`/`dirname \"$quoted_absolute_path\" | cut -c 3-`/`basename \"$quoted_absolute_path\"`"
    fi
    
    # find absolute path (parent path times ".." will not be striped path items)
    quoted_absolute_path=$(echo $quoted_absolute_path | grep '^/' || echo `pwd`/$quoted_absolute_path)
    
    # Reset Link Counter
    n_links_followed=0
    # Check if there are any symlinks
    resolve_symlinks
}



#
#  Mail Functions
#

# Checks the path of the mailconfigpartner has context
# If there is no context the assume a context of the backup config
function check_mailconfigpartner {
    # Check for './' and '/' at the start

    local mailconfigpartner_name=""
    local dot_slash_test=`echo "$mailconfigpartner" | grep '^./'`
    local slash_test=`echo "$mailconfigpartner" | grep '^/'`
    if [ "$dot_slash_test" == "" ]  &&  [ "$slash_test" == "" ] ; then
        # If the mailconfigpartner has no context then assume it is in
        # the same directory as the backup_config file
        if [ "${mailconfigpartner}" != "" ] ; then 
            local mailconfigpartner_name=`basename $mailconfigpartner`
        else
            echo "" | tee -ai $logFile
            echo "WARNING! : No mail configuration partner specified." | tee -ai $logFile
            echo "           To specify a mail partner configuration file add the" | tee -ai $logFile
            echo "           following line into your backup configuration file :" | tee -ai $logFile
            echo ""  | tee -ai $logFile
            echo "           mailconfigpartner=nameofyourmailpartner.conf" | tee -ai $logFile
            echo ""  | tee -ai $logFile
        fi
        mailconfigpartner="${backupConfigurationFolderPath}/${mailconfigpartner_name}"
    fi
}


# Send Mail Functions  
# Sends an email out
function send_mail_log  {
    
    if [ "${disable_mailconfigpartner}" != "YES" ] ; then
        check_mailconfigpartner
    fi
    
    ## Close Log File
    echo "" >> $logFile
    echo "" >> $logFile
    
    if [ "${disable_mailconfigpartner}" != "YES" ] ; then
        bash $currentdir/$mailScriptName "$mailconfigpartner"
    fi
    
    return 0
} 


# Backup Destination Check
# Check that the backup destination directory is available 
function local_backup_destination_availible  {
	# Actually we only check if there is something (not that is a directory) this allows people to
	# configure links for the backup. An error will be reported if rsync is not able to copy files
	# this is just a basic pre flight check.
	if ! [ -e "${backupDest}" ] ; then
		# It may be good to have further options such run a script to mount or make this destination available - for another version.
		echo "ERROR! : Local backup destination is not currently available." | tee -ai $logFile
		echo "         Destination : $backupDest" | tee -ai $logFile
		echo "         Backup Cancelled." | tee -ai $logFile
		send_mail_log
		exit -1
	fi
}


# Backup Source Check
# Check that the backup source is availible 
function local_backup_source_availible  {
	# Actually we only check if there is something (not that is a directory) this allows people to
	# configure links for the backup. An error will be reported if rsync is not able to copy files
	# this is just a basic pre flight check.
	if ! [ -e "${backupSource}" ] ; then
		# It may be good to have further options such run a script to mount or make this source available - for another version.
		echo "ERROR! : Local backup source is not currently available." | tee -ai $logFile
		echo "         Source : $backupSource" | tee -ai $logFile
		echo "         Backup Cancelled." | tee -ai $logFile
		send_mail_log
		exit -1
	fi
}


function confirm_backup_integraty {

    # confirm the integrity of the backup sets - no missing in the sequence
    # note : for the future revision configuration option - if the section.0 is missing this is not a problem other than disk space usage
    #        and as such, current_set_section_num could be set to start at 1 rather than 0 with an option.
	first_integrety_issue_detected=""
    current_set_section_num=0
    largest_section_in_set=`ls "${backupDest}/" | grep -e "Section.[0-9]\+" | awk -F "." '{print $2}' | sort -n | awk '{ print $NF }' | tail -n 1`
    #  If there are no pre-existing sections then skip the checks.
    if [ "${largest_section_in_set}" != "" ] ; then 
        confirmed_section_num=-1
        set_section_integrity_confirmed="NO"
        while [ $current_set_section_num -le $largest_section_in_set ] ; do
        	if [ -e "${backupDest}/Section.${current_set_section_num}" ] ; then
        		((confirmed_section_num++))
			else
				if [ "${first_integrety_issue_detected}" == "" ] ; then
					first_integrety_issue_detected="${current_set_section_num}"
				fi
			fi
        	((current_set_section_num++))
        done
        ((current_set_section_num--))
        if [ $confirmed_section_num -eq $current_set_section_num ] ; then
        	set_section_integrity_confirmed="YES"
        fi
        if [ "${set_section_integrity_confirmed}" != "YES" ] ; then 
            echo "ERROR! : Backup set integrity is in question."  | tee -ai $logFile
            echo "         Before backup snapshot rotation begins, your backup set" | tee -ai $logFile
            echo "         snapshot sections must be in complete sequence." | tee -ai $logFile
            echo "         Backup set destination directory : ${backupDest}" | tee -ai $logFile
			echo "         Frist integrity error detected in Section.${first_integrety_issue_detected}" | tee -ai $logFile
        	if [ "$post_actions_on_backup_error" == "YES" ] ; then
                # We are going to run post actions even though the backup has failed
                perform_post_action_scripts
            fi
            send_mail_log
            exit -1
        fi
    
        # Check for sections which extend beyond the currently configured rotation management range
        if [ $largest_section_in_set -ge $numRotations ] ; then
            # Looks like there are some sections which are not going to be managed
            # and as such we will display a warning and list the unmanaged rotations
            current_set_build_reccomended_removal_set=$numRotations
            backup_sets_reccomended_for_manual_removal=""
            while [ $current_set_build_reccomended_removal_set -le $largest_section_in_set ] ; do
                        backup_sets_reccomended_for_manual_removal="${backup_sets_reccomended_for_manual_removal} Section.${current_set_build_reccomended_removal_set}"
                        ((current_set_build_reccomended_removal_set++))
            done
            backup_sets_reccomended_for_manual_removal=`echo "${backup_sets_reccomended_for_manual_removal}" | cut -c 2-`
            echo "WARNING! : Unmanaged sections detected within backup set; backup will continue."
            echo "           Consider the manual removal of the following unmanaged sections :"
            echo "           ${backup_sets_reccomended_for_manual_removal}"
        fi
    fi
}


# Post Action Functions 
# Performs the post action scripts
function perform_post_action_scripts {
     
    # Perform Post Action Scripts
    if [ -s "${backup_post_action}" -a -x "${backup_post_action}" ] ; then
        
        echo "Checking for Post Action Scripts..."
        
        # Export Appropriate variables to the scripts
        export logFile                        # post scripts have the ability to write data to the log file.
        export rsync_session_log_file         # post scripts may want to reference this file.
        export backupConfigurationFolderPath  # should have been done previously anyway.
        export backup_status                  # provides feed back regarding the status of the backup.
        export backupSource                   # provides the directory we are backing up (carful may be remote).
        export backupDest                     # provides the directory we are storing the backups (carful may be remote).
        export rsync_session_log_name         # provides the name of the rsync session log (file may or may not exit)
        export numRotations                   # number of rotations exported.
        
        # This is only required for the post action not for the pre action 
        export pre_backup_script_status       # provides access to the pre status of the pre backup script actions.
        
        # Export the SSH information from the configruation file (probably not required)
        export useSSH
        export sshSource
        export sshRemoteUser
        export sshRemoteServer
        
        # Export the Script Return Codes
        export SCRIPT_SUCCESS
        export SCRIPT_WARNING
        export SCRIPT_HALT
        
        
        
        # Execute the Post Backup Actions (passing all parameters passed to the script)
        "${backup_post_action}" $*
        
        # Store the Exit Value from the Pre Backup Script
        backup_post_action_exit_value=$?
        
        
        if [ ${backup_post_action_exit_value} != ${SCRIPT_SUCCESS} ] ; then 
            
            # Determin weather script errors should be reported ( this will affect backup success status )
            if [ ${backup_post_action_exit_value} == ${SCRIPT_HALT} ] ; then 
                echo 1>&2 "" | tee -ai $logFile
                echo 1>&2 "ERROR! : One or more post backup action scripts exited with halt requests. " | tee -ai $logFile
                echo 1>&2 "         Backup stopping..." | tee -ai 
                echo 1>&2 "" | tee -ai $logFile
                backup_status="FIALED"
            fi
            
            # Check for Warning exit codes
            if [ ${backup_post_action_exit_value} == ${SCRIPT_WARNING} ] ; then 
                echo 1>&2 "" | tee -ai $logFile
                echo 1>&2 "WARNING! : One or more post backup action scripts exited with warnings." | tee -ai $logFile
                echo 1>&2 "           Backup continuing..." | tee -ai 
                echo 1>&2 "" | tee -ai $logFile
            else
                
                # Report Undefined Exit Value
                echo 1>&2 "" | tee -ai $logFile
                echo 1>&2 "WARNING! : Undefined post action exit value : ${backup_post_action_exit_value}" | tee -ai $logFile
                echo 1>&2 "           Backup continuing..." | tee -ai 
                echo 1>&2 "" | tee -ai $logFile
            fi
        fi
    fi
}


function sync_file_systems {
    # This function essentally just issues the sync command to the system if it is availible and then waits for disks
    local sync_executable="/bin/sync"
    if [ -f "${sync_executable}" ] ; then
        "${sync_executable}"
    fi
    sleep 7
}


function make_seconds_human_readable {
	# This function will accept an argument of seconds and convert this to human reable output - the return value is stored in a varible.
	difference_in_seconds="$1"
	less_than_one_second_string=""
	time_to_human_days=`echo "scale=0 ; $difference_in_seconds / 86400" | bc -l`
	time_to_human_hours=`echo "scale=0 ; ($difference_in_seconds / 3600) - ($time_to_human_days * 24)"  | bc -l `
	time_to_human_minutes=`echo "scale=0 ; ($difference_in_seconds / 60) - ($time_to_human_days * 1440) - ($time_to_human_hours * 60)" | bc -l`
	time_to_human_seconds=`echo "scale=0 ; $difference_in_seconds % 60" | bc -l`
    if [ ${time_to_human_days} == 0 ] && [ ${time_to_human_hours} == 0 ] && [ $time_to_human_minutes == 0 ] && [ ${time_to_human_seconds} == 0 ] ; then
        less_than_one_second_string=" (less than one second)"
    fi 
	return_value_from_make_seconds_human_readable="${time_to_human_days} days, ${time_to_human_hours} hours, ${time_to_human_minutes} minutes, ${time_to_human_seconds} seconds${less_than_one_second_string}"
}


##################################
##      Pre Loaded Settings     ##
##################################

# Configuration may override these default settings

# Is the source for this backup located on a remote machine accessed via SSH (YES/NO) 
useSSH="NO"

# Backup Pre and Post Action Script Variable Initializers - leave these blank
backup_pre_action_script=""
backup_post_action_script=""

# Growl Notifcation
sendGrowlNotification="NO"

# Remote Rsync Path Settings for network backup via SSH
ssh_rsync_path_remote=""
default_ssh_rsync_path_remote_darwin="/usr/bin/rsync"
custom_ssh_rsync_path_remote_darwin="/usr/local/bin/rsync"
ssh_rsync_path_remote_overidden_by_configuration="NO"

# Local Rsync Path Settings for network backup via SSH
ssh_rsync_path_local=""
default_ssh_rsync_path_local_darwin="/usr/bin/rsync"
custom_ssh_rsync_path_local_darwin="/usr/local/bin/rsync"
ssh_rsync_path_local_overidden_by_configuration="NO"

# Local Rsync Path Settings for local backup 
# (fine provided we are running Mac OS 10.4.x or greater)
rsync_path_local=""
default_rsync_path_local_darwin="/usr/bin/rsync"
rsync_path_local_overidden_by_configuration="NO"

custom_rsync_path_local_darwin=""
default_custom_rsync_path_local_darwin="/usr/local/bin/rsync"
custom_rsync_path_local_darwin_overidden_by_configuration="NO"

# Ignore code 24 rsync - some files vanished before they could be transferred errors
ignore_rsync_vanished_files=""
default_ignore_rsync_vanished_files="NO"

# Local System Check
check_local_system=""
default_local_system_check="YES"

# Remote System Check
# (NOT CURRENTLY IN USE REQUIRES FURTHER TESTING + DO YOU WANT TO HAVE ANOTHER PASSWORD PROMPT OR HOLE IN SSH WRAPPER)
check_remote_system=""
default_remote_system_check="NO"

# Use Standard Version of Rsync
ssh_permit_standard_rsync_version=""
default_ssh_permit_standard_rsync_version="NO"

# Logging of Modified Files
change_options=""
itemize_changes_to_standard_log="NO"
enable_rsync_session_log="NO"
rsync_session_log_name=""
default_rsync_session_log_name="rsync_session.log"

# Locking of Backup Session
ignore_backup_lock=""
default_ignore_backup_lock="NO"
backup_lock_file_name="backup_in_progress.lock"
backup_lock_file_absolute_path=""

# Post actions performed on backup error.
post_actions_on_backup_error=""
default_post_actions_on_backup_error="NO"

# Email Reporting lmail settings.
defautl_mailconfigpartner=""
mailconfigpartner=""
email_and_archive_log_on_successful_backup=""
default_email_and_archive_log_on_successful_backup="NO"
disable_mailconfigpartner=""
default_disable_mailconfigpartner="NO"

# source and destination checks
local_backup_and_source_availibility_checks_enabled=""
default_local_backup_and_source_availibility_checks_enabled="YES"

# permission checks
default_abort_if_permisions_on_volume_not_set="YES"
abort_if_permisions_on_volume_not_set=""

# disable_acl_preservation
disable_acl_preservation=""
default_disable_acl_preservation="NO"

# backup configuration version
backupConfigurationVersion=""
backupConfigurationsVersionSet="NO"

# numberic permissions (--numeric-ids) configuration 
numeric_ids_enabled=""
default_numeric_ids_enabled="NO"

# bandwidth limiting (--bwlimit) configuration 
bandwidth_limit_enabled=""
default_bandwidth_limit_enabled="NO"
bandwidth_limit=""
default_bandwidth_limit=0

# preservation of hard links (--hard-links) configuration
hardlinks_enabled=""
default_hardlinks_enabled="NO"

# checksum enabled (--checksum) configuration 
checksum_enabled=""
default_checksum_enabled="NO"

# display information on how long some operations of the backup procedure take
# other varibles for timing information is found in the internal varioble section.
# reporting of snap shot times
report_snapshot_time_human_readable=""
default_report_snapshot_time_human_readable="NO"
report_snapshot_time_seconds=""
default_report_snapshot_time_seconds="NO"
# reporting of removal times
report_removal_times_human_readable=""
default_report_removal_times_human_readable="NO"
report_removal_times_seconds=""
default_report_removal_times_seconds="NO"
# These options are not part of the config example. 
# They may be set - but not nessasaryly honered.
report_removal_time_for_oldest_snap_shot_human_readable=""
default_report_removal_time_for_oldest_snap_shot_human_readable="NO"
report_removal_time_for_oldest_snap_shot_seconds=""
default_report_removal_time_for_oldest_snap_shot_seconds="NO"
report_removal_time_for_incomplete_backup_human_readable=""
default_report_removal_time_for_incomplete_backup_human_readable="NO"
report_removal_time_for_incomplete_backup_seconds=""
report_report_removal_time_for_incomplete_backup_seconds="NO"




##################################
##      Load Configuration      ##
##################################


# Absolute path to configuration script (passed in $1)
quoted_absolute_path=$1; get_absolute_path
export backupConfigurationFilePath="$quoted_absolute_path"
# Absolute path to configuration folder
export backupConfigurationFolderPath=`dirname "$backupConfigurationFilePath"`

echo "$backupConfigurationFilePath" | tee -ai $logFile
echo "Loading Backup Script Configuration Data..." | tee -ai $logFile

# Check file specified exists and is a lbackup command file.
if ! [ -f "$backupConfigurationFilePath" ] ; then 
    echo 1>&2 "ERROR! : Specified configuration file dose not exist" | tee -ai $logFile
    echo      "         File Referenced : $backupConfigurationFilePath" | tee -ai $logFile
    exit -127
fi

# Load configuration file parsed in to as argument $1
source "$backupConfigurationFilePath"



###########################################
##     Post Config Load Configuration    ##
###########################################


# Configure the Default Remote Rsync Path for network backups unless it has already been specified in the configuration file.
if [ "$ssh_rsync_path_remote" == "" ] ; then
	ssh_rsync_path_remote="${default_ssh_rsync_path_remote_darwin}"
else
	ssh_rsync_path_remote_overidden_by_configuration="YES"
fi

# Local source and destination available checks (unable to modify from configuration file at present)
local_backup_and_source_availibility_checks_enabled="${default_local_backup_and_source_availibility_checks_enabled}"

# Configure the default local rsync path for network backups unless it has already been specified in the configuration file.
if [ "$ssh_rsync_path_local" == "" ] ; then
	ssh_rsync_path_local="${default_ssh_rsync_path_local_darwin}"
else
	ssh_rsync_path_local_overidden_by_configuration="YES"
	
	# If we are using SSH then the local version of rsync will need to be set to the local version of rsync specified in the config file
	if [ "${useSSH}" == "YES" ] ; then
	    custom_rsync_path_local_darwin="${ssh_rsync_path_local}"
    fi
fi

rsync_session_log_file=""
# Curenlty this is not an option in the configuration. The line below ensures this can not be set in the config file.
rsync_path_local=""
# Configure the default local rsync path for local backups unless it has already been specified in the configuration file.
if [ "$rsync_path_local" == "" ] ; then
	rsync_path_local="$default_rsync_path_local_darwin"
else
	rsync_path_local_overidden_by_configuration="YES"
fi

# Check if the custom_rsync_path_local_darwin has been set in the configuration.
if [ "$custom_rsync_path_local_darwin" == "" ] ; then
	custom_rsync_path_local_darwin="$default_custom_rsync_path_local_darwin"
else
	custom_rsync_path_local_darwin_overidden_by_configuration="YES"
fi

# Currently this is not an option in the configuration. The line below ensures this can not be set in the config file.
rsync_session_log_name="${default_rsync_session_log_name}"

# Are we going to be using the standard version of rsync and then setting the appropriate flags
if [ "$ssh_permit_standard_rsync_version" == "" ] ; then
	ssh_permit_standard_rsync_version="$default_ssh_permit_standard_rsync_version"
fi

# Are we going to check the local system for a spcifc version of rsync and set appropriate options.
if [ "$check_local_system" == "" ] ; then
	check_local_system="$default_local_system_check"
fi

# Are we going to check the remote system for a specific version of rsync and set appropriate options.
# (NOT CURRENTLY IN USE REQUIRES FURTHER TESTING + DO YOU WANT TO HAVE ANOTHER PASSWORD PROMPT OR HOLE IN SSH WRAPPER)
if [ "$check_remote_system" == "" ] ; then
	default_remote_system_check="$default_remote_system_check"
fi

# Are we going to ignore backup locks with this configuration
if [ "$ignore_backup_lock" == "" ] ; then
	ignore_backup_lock="$default_ignore_backup_lock"
fi

# Are we going to carry on with post configurations if there is an error during the backup
if [ "$post_actions_on_backup_error}" == "" ] ; then
        default_post_actions_on_backup_error="NO"
fi

# mailconfigpartner file name
if [ "$mailconfigpartner" == "" ] ; then
        mailconfigpartner="$defautl_mailconfigpartner"
fi

# check for the reporting options regarding email.
if [ "$email_and_archive_log_on_successful_backup" == "" ] ; then
        email_and_archive_log_on_successful_backup="$email_and_archive_log_on_successful_backup"
fi

# check that the email reporting settings are valid.
if [ "$email_and_archive_log_on_successful_backup" == "YES" ] && [ "$mailconfigpartner" == "" ] ; then
        echo "WARNING! :  Error in the configuration file. Unable to follow configuration instructions." | tee -ai $logFile
        echo "            The \"email_and_archvie_log_on_sucessful_backup\" option is set to \"YES\"." | tee -ai $logFile
        echo "            However, there is no \"mailconfigpartner\" file (lmail configuration) specified" | tee -ai $logFile
        echo "            within the specified backup configuration. Backup will continue." | tee -ai $logFile
        echo "            However, no email reporting or archiving will be attempted, upon successful backup." | tee -ai $logFile
fi

# chcek for any permission check directives.
if [ "$abort_if_permisions_on_volume_not_set" == "" ] ; then
	abort_if_permisions_on_volume_not_set="$default_abort_if_permisions_on_volume_not_set"
fi

# Is the configuarion version set
if [ "${backupConfigurationVersion}" != "" ] ; then
    # This should be improved to check for intergers and possibly even report errors if the minimum version 
    # has not been meet by the configuation file.
    backupConfigurationsVersionSet="YES"
fi

# Check if the acl preservation has been set within the configuration file
if [ "$disable_acl_preservation" == "" ] ; then 
    disable_acl_preservation="$default_disable_acl_preservation"
fi

# Check if the numeric id preservation has been set within the configuration file
if [ "$numeric_ids_enabled" == "" ] ; then 
    numeric_ids_enabled="$default_numeric_ids_enabled"
fi

# Check if the bandwidth limiting has been set within the configuration file
if [ "$bandwidth_limit" == "" ] ; then 
    bandwidth_limit_enabled="$default_bandwidth_limit_enabled"
	bandwidth_limit="$default_bandwidth_limit"
else
	if [ ${$bandwidth_limit} -gt 0 ] ; then
		bandwidth_limit_enabled="YES"
		bandwidth_limit=${$bandwidth_limit}
	else
		bandwidth_limit_enabled="NO"
	fi
fi

# Check if the preservation of hard links has been set within the configuration file
if [ "$hardlinks_enabled" == "" ] ; then 
    hardlinks_enabled="$default_hardlinks_enabled"
fi

# Check if the numeric checksum option has been enabled within the configuration file
if [ "$numeric_ids_enabled" == "" ] ; then 
    checksum_enabled="$default_checksum_enabled"
fi

# Check if removal times will be reported in human readable format
if [ "$report_removal_times_human_readable" == "" ] ; then
	report_removal_times_human_readable="$default_report_removal_times_human_readable"
fi
if [ "${report_removal_times_human_readable}" == "YES" ] ; then
	report_removal_time_for_oldest_snap_shot_human_readable="YES"
	report_removal_time_for_incomplete_backup_human_readable="YES"
fi

# Check if the removal times will be reported in seconds (machine / easily graphable format)
if [ "$report_snapshot_time_seconds" == "" ] ; then
	report_snapshot_time_seconds="$default_report_snapshot_time_seconds"
fi
if [ "${report_snapshot_time_seconds}" == "YES" ] ; then
	report_removal_time_for_oldest_snap_shot_seconds="YES"
	report_removal_time_for_incomplete_backup_seconds="YES"
fi

# Check if snapshot times will be reported in human readable format
if [ "${report_snapshot_time_human_readable}" == "" ] ; then
  report_snapshot_time_human_readable="$default_report_snapshot_time_human_readable"
fi

# Check if snapshot times will be reported in seconds (machine / easily graphable format)
if [ "${report_snapshot_time_seconds}" == "" ] ; then
  report_snapshot_time_seconds="$default_report_snapshot_time_seconds"
fi

# Check if we will disable the email system (no emails will be sent)
if [ "${disable_mailconfigpartner}" == "" ] ; then
    disable_mailconfigpartner="$default_disable_mailconfigpartner"
fi

# Check if we be ingnoring rsync vanished file errors
if [ "ignore_rsync_vanished_files" == "" ] ; then
  ignore_rsync_vanished_files="default_ignore_rsync_vanished_files"
fi

if [ "$disable_mailconfigpartner" == "YES" ] && [ "$email_and_archive_log_on_successful_backup" == "YES" ] ; then
        echo "WARNING! :  Error in the configuration file. Unable to follow configuration instructions." | tee -ai $logFile
        echo "            The \"email_and_archvie_log_on_sucessful_backup\" option is set to \"YES\"." | tee -ai $logFile
        echo "            However, the \"disable_mailconfigpartner\" option is also set to \"YES\"." | tee -ai $logFile
        echo "            The \"disable_mailconfigpartner\" option has been set to \"NO\"." | tee -ai $logFile
        disable_mailconfigpartner="NO"
fi





#####################################
##     Additional Configuration    ##
#####################################

# Utilities
utilities_folder_name="utilities"



########################
## Internal Variables ##
########################

##
## Timing varibles
##

# Time reporting : oldest backup to be rotated off - deletion times
epoch_before_oldest_remove=""
epoch_after_oldest_remove=""
total_time_required_for_oldest_snap_shot_removal_in_seconds=""

# Time reporting : incomplete backup - deletion time
epoch_before_incomplete_remove=""
epoch_after_incomplete_remove=""
total_time_required_for_incomplete_backup_removal_in_seconds=""

# Time reporting : rsync run time
epoch_before_rsync_run=""
epoch_after_rsync_run=""
total_time_required_for_snapshot_in_seconds=""

# Time reporting : overall successful backup
epoch_successful_backup_start=""
epoch_successful_backup_finished=""
total_time_required_for_successful_backup_in_seconds=""
 
# # Time reporting : pre-action scripts
# epoch_before_pre-action_scripts=""
# epoch_after_pre-action_scripts=""
# total_time_required_for_pre-action_scripts=""
# 
# # Time reporting : post-action scripts
# epoch_before_post-action_scripts=""
# epoch_after_post-action_scripts=""
# total_time_required_for_post-action_scripts=""

# Backup Results
backupResult=""
newBackupResult=""
backupResultRsyncErrorCheck=""

# Name of the Mail Script
mailScriptName="maillog_script.bash"

# Backup and Link Paths
backupDestSlash=`echo "$backupDest" | sed 's/\ /\\ /g'`
backupDestCRot=$backupDestSlash/Section.0
backupDestCRotTemp=$backupDestSlash/Section.inprogress
linkDest=$backupDestSlash/Section.0

createLinks="NO"
sshSource="$sshRemoteUser""@""$sshRemoteServer"

# Get The Backup Scripts Absolute Path
quoted_absolute_path=$0; get_absolute_path
currentfilepath="$quoted_absolute_path"
currentdir=`dirname "$currentfilepath"`

# Set The Utilities Directory Absolute Path 
utilitiesdir="$currentdir""/""$utilities_folder_name"

# Internal Configuration
log_dirPath="$backupConfigurationFolderPath"
logFile="$log_dirPath""/""$log_fileName"
EXCLUDES="$backupConfigurationFolderPath"/$excludes_filename

# Darwin Volume Permission Checks
backupDestVolume=""
permissions_on_volume=""

# Configuration file input checking
number_of_rotations_is_positive_integer="YES"

# Logging of modified/transfered files
if [ "${enable_rsync_session_log}" == "YES" ] ; then
	rsync_session_log_file="${log_dirPath}/${rsync_session_log_name}"
	test_for_spaces=`echo "${rsync_session_log_file}" | grep " "`
        if [ "${test_for_spaces}" != "" ] ; then
		echo "WARNING! : Unsupported configuration. The results could be unexpected."
		echo "           When creating a secondary log file, the path to this log file"
		echo "           must not contain any spaces"
	fi
fi
if [ "${itemize_changes_to_standard_log}" == "YES" ] && [ "${enable_rsync_session_log}" != "YES" ] ; then
	change_options="--itemize-changes"
fi
if [ "${enable_rsync_session_log}" == "YES" ] && [ "${itemize_changes_to_standard_log}" != "YES" ] ; then
	change_options="--log-file=${rsync_session_log_file}"
fi
if [ "${enable_rsync_session_log}" == "YES" ] && [ "${itemize_changes_to_standard_log}" == "YES" ] ; then
	echo "WARNING! : Unsupported configuration. The results may be unexpected."
	echo "           Logging changes to both the primary and secondary log files"
	echo "           simultaneously is enabled."
	change_options="--itemize-changes --log-file=${rsync_session_log_file}"
fi

if [ "${numeric_ids_enabled}" == "YES" ] ; then
	numeric_id_options="--numeric-ids"
fi

if [ "$hardlinks_enabled" == "YES" ] ; then
	preserve_source_hardlink_options="--hard-links"
fi

if [ "${checksum_enabled}" == "YES" ] ; then
	checksum_options="--checksum"
fi


# Default Pre and Post Script
default_scripts="$utilitiesdir""/""default_scripts"
backup_pre_action="$default_scripts""/""default_backup_pre_action.bash"
backup_post_action="$default_scripts""/""default_backup_post_action.bash"

# Path to Script Return Codes
script_return_codes="$default_scripts""/""script_return_codes.conf"


# Stores Status of Pre Backup Action Script
pre_backup_script_status="FAILED"

# Stores Status of Backup
backup_status="SUCCESS"

# Backup Locking (absolute path to this configurations lock file)
backup_lock_file_absolute_path="$backupConfigurationFolderPath""/""$backup_lock_file_name"



##############################
## Load Script Return Codes ##
##############################

# Check script return codes file exists.
if ! [ -f "${script_return_codes}" ] ; then
    echo 1>&2 "ERROR! : Script Return Codes can not be loaded" | tee -ai $logFile
    echo      "         File Referenced : $script_return_codes" | tee -ai $logFile
    exit -127
fi


# Load the Script Return Codes
source "${script_return_codes}"


###########################
## Varible Configuration ##
###########################
# Set up of varibles based upon what
# was set within the configuration file

# Default Script Varible Configuration
if [ "$backup_pre_action_script" != "" ] && [ -f "$backup_pre_action_script" ] ; then
    backup_pre_action="$backup_pre_action_script"
fi
if [ "$backup_post_action_script" != "" ] && [ -f "$backup_post_action_script" ] ; then
    backup_post_action="$backup_post_action_script"
fi



########################
##  Preflight Check   ##
########################

# start total backup timer running
epoch_successful_backup_start=`date "+%s"`

# update logfile
echo "##################" >> $logFile
echo `date` >> $logFile
echo "" >> $logFile

# Check for a backup lock and other lock related tasks if it has not been disabled
if [ "$ignore_backup_lock" == "NO" ] ; then
        
        # Check for the lock file
        if [ -f "$backup_lock_file_absolute_path" ] ; then
                # It may be good to have further options such as how long ago was the lock file generated etc (ie should the lock be ignored)
                echo "ERROR! : Backup configuration lock file present : $backup_lock_file_absolute_path" | tee -ai $logFile
                echo "         Backup Cancelled." | tee -ai $logFile
                exit -1
        fi
        
        # Test the ability to write the lock file and report an error if there was one.
        touch "$backup_lock_file_absolute_path" 2>/dev/null
        if [ $? != 0 ] ; then
                echo "ERROR! : Unable to generate backup lock file : $backup_lock_file_absolute_path" | tee -ai $logFile  
				echo "         Backup Cancelled." | tee -ai $logFile
				exit -1
		else
			# Save the backup start time since epock into line 1 of the lock file
			echo "Process start time (seconds since epoch) : ${epoch_successful_backup_start}" >> "${backup_lock_file_absolute_path}"	
			if [ $? != 0 ] ; then
				echo "ERROR! : Unable to load backup start time into lock file : $backup_lock_file_absolute_path" | tee -ai $logFile  	
				echo "         Backup Cancelled." | tee -ai $logFile
				rm -f "$backup_lock_file_absolute_path"
				exit -1
			fi
			# Save the PID into line 2 of the lock file
			echo "Process PID : ${$}" >> "${backup_lock_file_absolute_path}"	
			if [ $? != 0 ] ; then
				echo "ERROR! : Unable to load PID into lock file : $backup_lock_file_absolute_path" | tee -ai $logFile  	
				echo "         Backup Cancelled." | tee -ai $logFile
				rm -f "$backup_lock_file_absolute_path"
				exit -1
			fi
		fi
        
        # Set a trap so that if the backup is unexpectedly exited the lock file will be removed.
        #
        # Note :  Since LBackup v 0.9.8r3-alpha3 the exit status is now allowed to be what ever the exit status was set.
        #         To revert to the original behavior add an "exit 0" command within the trap. This will insure 
        #         that exit 0 will be returned. This note will be handy if you have such a requirement.
        #
        trap "{ sleep 0.5 ;rm -f \"$backup_lock_file_absolute_path\"; }" EXIT      

else
        # Skip backup lock file check notification not written to the log file on purpose (for this version).
        echo "Backup lock file check skipped." 
fi


# Check that a number of rotations has been configured within the backup configuration and that this is a positive and non zero integer.
# There must be a better way of achiving this... suggestions welcome. "[ $x -eq $x 2> /dev/null ]" will not sort out the negitive integers.
if [ $(echo "$numRotations" | grep -E "^[0-9]+$") ] ; then
    # integers could have leading zeros if they do then we need to remove them for use with bash processing
    echo "$numRotations" | grep -v '^0' > /dev/null
    if [ $? != 0 ] ; then 
        # If there are leading zeros and the command below is successful then the leading zeos will be stripped as bash
        # is not capable of dealing with integers with leading zeros
        numRotations=`echo "${numRotations} * 1" | bc`
        if [ $? != 0 ] || [ $numRotations == 0 ] ; then
            # no bc installed on system or the integer is zero, either way it is not going to work.
 	        number_of_rotations_is_positive_integer="NO"
        fi
    fi
else
  # not a positive integer (excluding zero) 
  number_of_rotations_is_positive_integer="NO"
fi
if [ "${number_of_rotations_is_positive_integer}" != "YES" ] ; then
  # So the number of rotations spceified is not valid.
  # Report the problem to the log and send a mail off regarding the configuration issue.
  echo "" | tee -ai $logFile
  echo "CONFIGURATION ERROR! : The number of rotations must be specified as a positive integer."  | tee -ai $logFile
  echo "                       Insure that your backup configuration specifies the number of" | tee -ai $logFile
  echo "                       rotations as a positive integer by using syntax listed below : "  | tee -ai $logFile
  echo "                       numRotations=<positive integer>" | tee -ai $logFile
  echo "" | tee -ai $logFile
  echo "                       Below is an example which specifies eight rotations :" | tee -ai $logFile
  echo "                       numRotations=8" | tee -ai $logFile
  echo "" | tee -ai $logFile
  send_mail_log
  exit -1
fi

# If the email subsystem has been disabled via the configuration file then att this information to the log.
if [ "${disable_mailconfigpartner}" == "YES" ] ; then 
    echo "Email reporting is disabled." | tee -ai $logFile
fi

# Wake Client
if [ "$WAKE" == "YES" ] ; then
	echo "Waking Client : $hardware_address..." | tee -ai $logFile  
	python $utilitiesdir/wake.py $hardware_address
	sleep 10
fi

# Check if The Client is up

# Ping Test - Quick Test
if [ "$PingTest" == "YES" ] ; then
    echo "Testing ICMP Connection..." | tee -ai $logFile
    pingTest=`ping -qc 5 $sshRemoteServer | grep 100%`
    if [ "$pingTest" != "" ] ; then
        echo "Server Down"  | tee -ai $logFile

        ## Close Log File
        echo "" >> $logFile
        echo "" >> $logFile
        
        # Remove the backup lock file - probably not required - this will be handled by the trap
        rm -f "$backup_lock_file_absolute_path"
        exit -1
    fi
fi



# SSH Test - If host device is operating though NAT
if ( [ "$SSHTest" == "YES" ] && [ "$useSSH" == "YES" ] ) ; then
    echo "Testing SSH Connection..." | tee -ai $logFile
    SSHTest=`ssh $sshSource "##--LBackup_SSH_Test--## ; exit 0" 2> /dev/null`
    SSHTestResult=${?}
    if ( [ "$SSHTest" != "This wrapper only supports rsync" ] && [ $SSHTestResult != 0 ] ); then
           echo "$SSHTest"  | tee -ai $logFile
           echo "SSH Test Failed" | tee -ai $logFile

           ## Close Log File
           echo "" >> $logFile
           echo "" >> $logFile
           
           # Remove the backup lock file - probably not required - this will be handled by the trap
           rm -f "$backup_lock_file_absolute_path"
           exit -1
   fi
fi 


# Check and report if the post action scripts are set to run even if there is an error.
if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # Make it clear that post actions will run even if the backup has failed
        echo "Even if the backup fails, Post-Action Scripts are Enabled" | tee -ai $logFile
fi

# Check if log file email and archving is configured to occor on a sucesfful backup.
if [ "$email_and_archive_log_on_successful_backup" == "YES" ] && [ "$mailconfigpartner" != "" ] ; then
        # Make it clear that lmail (archiving and log email reporting will take place even if the backup is successful.
        echo "Even if the backup is successful, lmail (log archiving and log email reporting) will run" | tee -ai $logFile
fi



# Perform Pre Action Scripts
if [ -s "${backup_pre_action}" -a -x "${backup_pre_action}" ] ; then
    
    echo "Checking for Pre Action Scripts..."
    
    # Export Appropriate variables to the scripts
    export logFile                        # pre scripts have the ability to write data to the log file
    export rsync_session_log_file         # pre scripts may want to use this log
    export backupConfigurationFolderPath  # should have been done previously anyway
    export backupSource                   # provides the directory we are backing up (carful may be remote)
    export backupDest                     # provides the directory we are storing the backups (carful may be remote)
    export rsync_session_log_name         # provides the name of the rsync session log (file may or may not exit).
    export numRotations                   # number of rotations exported.
    
    # Export the SSH information from the configruation file (probably not required)
    export useSSH
    export sshSource
    export sshRemoteUser
    export sshRemoteServer
    
    # Export the Script Return Codes
    export SCRIPT_SUCCESS
    export SCRIPT_WARNING
    export SCRIPT_HALT
    
    # Execute the Pre Backup Actions (passing all parameters passed to the script)
    "${backup_pre_action}" $*
    
    # Store the Exit Value from the Pre Backup Script
    backup_pre_action_exit_value=$?
    
    if [ ${backup_pre_action_exit_value} == ${SCRIPT_SUCCESS} ] ; then
        # Set Pre Backup Script Success Flag
        pre_backup_script_status="SUCCESS"
    else
        # Determin weather to proceed with the backup
        if [ ${backup_pre_action_exit_value} == ${SCRIPT_HALT} ] ; then 
            echo 1>&2 "ERROR! : Pre Backup Action Script Failed : Backup Aborted" | tee -ai $logFile
            
            if [ "$post_actions_on_backup_error" == "YES" ] ; then
                # We are going to run post actions even though the backup has failed
                perform_post_action_scripts
            fi
            
            send_mail_log
            
            # Remove the backup lock file - probably not required - this will be handled by the trap
            rm -f "$backup_lock_file_absolute_path"
            
            exit ${SCRIPT_HALT}
        fi
        # Check for other exit codes
        if [ ${backup_pre_action_exit_value} == ${SCRIPT_WARNING} ] ; then 
            echo 1>&2 "WARNING! : One or more pre backup action scripts resulted in warning : backup continuing..." | tee -ai $logFile
        else
            # Report Undefined Exit Value
            echo 1>&2 "WARNING! : Undefined Pre Action Exit Value : ${backup_pre_action_exit_value}" | tee -ai $logFile
            echo 1>&2 "           Backup Continuing..." | tee -ai 
        fi
    fi    
fi




##
## Check local source and destination are available ( now that we have run the pre-action scripts )
##

if [ "${local_backup_and_source_availibility_checks_enabled}" == "YES" ] ; then

    # Check local (only kind at the moment) backup directory is available. This may need to be changed in the future.
    # For now it is a basic check. It could potentially start a sub-system to make the backup device available.
    # This is not yet implemented or even planned. It is just a possibility.
    local_backup_destination_availible

    # Check if the backup source is available - currently only local. 
    # This will probably be extended to network backups in the future.
    if [ "$useSSH" != "YES" ] ; then
    	# The source is local so check if the local source is available
    	local_backup_source_availible
    fi
    
fi




# Report if this is the First Run
if ! [ -d "$backupDestCRot" ] ; then
	echo "First Run Full Copy..." | tee -ai $logFile
fi


if ! [ -f $EXCLUDES ] ; then
    echo "Exclude-definitions missing" | tee -ai $logFile
    
    # Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
    exit -127
fi  


# Check if Hard Links Are Required
if [ $numRotations -ge 1 ] ; then
	#Check if there are files to link to 
	if [ -d "$linkDest" ] ; then
		#make sure links are created
		createLinks="YES"
		echo "Hard Links Enabled" | tee -ai $logFile
	fi
fi


# Check whether the Last backup completed successfully
if [ -d "$backupDestCRotTemp" ] ; then
    successfully_removed_failed_backup="NO"
	echo "Previous Backup Failed" | tee -ai $logFile
  	echo "Removing Incomplete Backup...." | tee -ai $logFile
  	if [ "${report_removal_time_for_incomplete_backup_human_readable}" == "YES" ] || [ "${report_removal_time_for_incomplete_backup_seconds}" == "YES" ] ; then
  	    epoch_before_incomplete_remove=`date "+%s"`
    fi
	rm -Rf "$backupDestCRotTemp"
  	if [ $? != 0 ] ; then
        current_user=`whoami`
        if [ "${current_user}" != "root" ] ; then
            # Attempt to enable write access to the temporary files
            chmod -R +w "${backupDestCRotTemp}"
            # Try the removal again
            rm -Rf "$backupDestCRotTemp"
            if [ $? == 0 ] ; then
                successfully_removed_failed_backup="YES"
            fi 
        fi
	else
    	successfully_removed_failed_backup="YES"
    fi
    
    if [ "${successfully_removed_failed_backup}" != "YES" ] ; then
            
        backup_status="FIALED"
            
        echo "ERROR! : Removing Temporary Directory (previous failed backup)" | tee -ai $logFile
        if [ "$post_actions_on_backup_error" == "YES" ] ; then
            # We are going to run post actions even though the backup has failed
            perform_post_action_scripts
        fi
                
        send_mail_log

        # Remove the backup lock file - probably not required - this will be handled by the trap
        rm -f "$backup_lock_file_absolute_path"
        exit -1
    else
        echo "Incomplete Backup Removed" | tee -ai $logFile
        # If configured then report the time to remove the the failed backup
        if [ "${report_removal_time_for_incomplete_backup_human_readable}" == "YES" ] || [ "${report_removal_time_for_incomplete_backup_seconds}" == "YES" ] ; then
            epoch_after_incomplete_remove=`date "+%s"`
            # This may also be enabled as debug in the future
            total_time_required_for_incomplete_backup_removal_in_seconds=`echo "${epoch_after_incomplete_remove} - ${epoch_before_incomplete_remove}" | bc -l`
            return_value_from_make_seconds_human_readable=""
            if [ "${total_time_required_for_incomplete_backup_removal_in_seconds}" == "" ] ; then
                echo "WARNING! : Unable to calculate the total time required for deletion of incomplete snapshot." | tee -ai $logFile
            else
                if [ "${report_removal_time_for_incomplete_backup_human_readable}" == "YES" ] ; then
                    make_seconds_human_readable "${total_time_required_for_incomplete_backup_removal_in_seconds}"
                    echo "Time required for deletion of the incomplete backup : ${return_value_from_make_seconds_human_readable}" | tee -ai $logFile
                fi
                if [ "${report_removal_time_for_incomplete_backup_seconds}" == "YES" ] ; then
                    echo "Seconds required for deletion of the incomplete backup : ${total_time_required_for_incomplete_backup_removal_in_seconds}" | tee -ai $logFile
                fi
            fi
        fi
    fi
fi







########################
##   RSync Options    ##
########################

# Set Show Progress
showProgress="NO"

# Checks the Remote OS if this backup is via SSH  
# (NOT CURRENTLY IN USE REQUIRES FURTHER TESTING + DO YOU WANT TO HAVE ANOTHER PASSWORD PROMPT OR HOLE IN SSH WRAPPER)
if [ "$check_remote_system" == "YES" ] && [ useSSH="YES" ] ; then
	
	echo "Testing Remote System Type and Version..." | tee -ai $logFile
    check_remote_system_results=`ssh $sshSource "uname -rs"`
    remote_system_check_TestResult=${?}
	
	if [ ${remote_system_check_TestResult} != 0 ] || [ "${check_remote_system_results}" == "" ] ; then
		echo "ERROR! : Unable to determine remote system type or version." | tee -ai $logFile
		echo "         Check the remote host is reachable and if you are using key based authentication  that" | tee -ai $logFile
		echo "         any wrapper scripts allow remote access to calls to the command : \"uname -rs\"" | tee -ai $logFile
		
		# Remove the backup lock file - probably not required - this will be handled by the trap
        rm -f "$backup_lock_file_absolute_path"
		exit -127
	else
	
		# Calculate the remote system type and version
		remote_system_type=`echo ${check_remote_system_results} | awk '{ print $1 }'`
		remote_system_version=`echo ${check_remote_system_results} | awk '{ print $2 }'`

		# Log the System Type and Version	-- before this can be enabled we need to check the error checking code.	
		#echo "    Remote System Name : ${remote_system_type}" | tee -ai $logFile
		#echo "	  Remote System Version : ${remote_system_version}" | tee -ai $logFile
		
		if [ "${remote_system_type}" == "Darwin" ] ; then
			
			accept_default_rsync_darwin_remote_ssh="NO"
			
			# Calculate the remote major darwin version
			remote_system_major_version_darwin=`echo ${remote_system_version} | awk -F "." '{print $1}'`
			if [ $? != 0 ] ; then
				remote_darwin_version="ERROR"
			fi
				
			# Sets the minimum version of Darwin when using the remote version of the OS bundled version of rysnc ( darwin version 8 is equivilent to tiger )
			darwin_standard_rsync_minimum_version_remote=8

			# Determin wheather the standard version of rsync is acceptible for remote backup use
			# This is depeneded upon whather which major relase of Darwin is installed on the remote system.
			if [ "${remote_darwin_version}" != "ERROR" ] ; then
				if [ $remote_system_major_version_darwin -ge $darwin_standard_rsync_minimum_version_remote ] && [ "$useSSH" == "YES" ] ; then
					# Running a local backup on Mac OS X 10.4.x or greater so we accept the standard version of rsync
					# This line means we are using the default Mac OS X bundled version of rsync. This dose require
					# that we are running a good version and also not that resource forks, may take up more space.
		            accept_default_rsync_darwin_remote_ssh="YES"
				fi
			else 
				echo "ERROR! : Unable to determine major Darwin release version of the remote machine." | tee -ai $logFile
				
				# Remove the backup lock file - probably not required - this will be handled by the trap
                rm -f "$backup_lock_file_absolute_path"
				exit -127
			fi	
		fi
	fi 
fi



# Checks the Local OS
local_system_name=`uname`

if [ "$check_local_system" == "YES" ] ; then
	
	# This system has been tested on HFS+ formated partitions. It requires testing on other formats.

	# If LBackup is running on Darwin then lets set the appropriate options for a backup
    if [ "$local_system_name" == "Darwin" ] ; then
        
		# So we are running on Darwin, in which case there is probably some meta data which needs to be beacked up.

		# Check the version of Darwin which is running - ie 10.3.x / 10.4.x / 10.5.x ...etc
		local_darwin_version=`uname -r | awk -F "." '{print $1}'`
		if [ $? != 0 ] ; then
			local_darwin_version="ERROR"
		fi

        # Check if the disk permissions are enabled on the destination volume
        if [ -f /usr/sbin/vsdbutil ] ; then
            # okay the tool to check volume permissions is availible on this system so we will use it.
            echo "$backupDest" | grep -e "^/Volumes" 2>&1 > /dev/null
            if [ $? == 0 ] ; then
                # backup dest path is starting with "/Volumes" so now lets pull that volume from the path
                backupDestVolume=`echo "$backupDest" | awk -F "/" '{ print $1"/"$2"/"$3}' `
                if [ -d "${backupDestVolume}" ] ; then
                    # now lets run a check on that volume
                    
					# disabled - due to depretiation of the vsdbutil command - will not work all the time / on all systems
					# permissions_on_volume=`/usr/sbin/vsdbutil -c "${backupDestVolume}" | awk '{print $NF}' | awk -F "." '{print $1}'`
					# if [ "${permissions_on_volume}" != "enabled" ] ; then
					
					permissions_on_volume=`/usr/sbin/diskutil info "${backupDestVolume}" | awk '/Owners:/ {print $2}'`
                    if [ "${permissions_on_volume}" != "Enabled" ] ; then
                            # It is important to check for enabled. This is because if the permissions have not been explicitly
                            # set then the test will return the quoted volume rather than enabled or disabled.
                            echo "WARNING! : Permissions are disabled on backup destination volume." | tee -ai $logFile
							echo "" | tee -ai $logFile
                            echo "           It is recommended that permissions on the destination volume are enabled." | tee -ai $logFile
                            echo "           Failure to enable permissions will most likely result in the hard link system failing." | tee -ai $logFile
                            echo "           Permissions may be enabled for most local file systems by issuing the following command as root :" | tee -ai $logFile
                            echo "           /usr/sbin/vsdbutil -a \"$backupDestVolume\"" | tee -ai $logFile
							echo "" | tee -ai $logFile
							echo "           Check that the destination file system is directly attached storage or is a virtual file system." | tee -ai $logFile
							echo "           Network based file systems are unsupported backup destinations (for LBackup backup sets)." | tee -ai $logFile
							if [ "$abort_if_permisions_on_volume_not_set" == "YES" ] ; then
								echo "" | tee -ai $logFile
								echo "           Default configuration is to abort backup, if the permissions on a volume"  | tee -ai $logFile
								echo "           have not been set. You may override this setting in your configuration file."  | tee -ai $logFile
								echo "" | tee -ai $logFile
								echo "           Backup canceled." | tee -ai $logFile
								send_mail_log
								exit -1
							fi
                    fi
                fi
            fi
        fi

		# Check if there are any custom rsync versions installed locally
        if [ -f ${custom_rsync_path_local_darwin} ] ; then
            installed_rsync_version=`${custom_rsync_path_local_darwin} --version | head -n 1`
            
            # Gathter Some Additional Information Regarding the Current Version of Rsync
            installed_rsync_version_number=`${custom_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}'`
            installed_rsync_version_number_major=`${custom_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}' | awk -F "." '{print $1}'`
            installed_rsync_version_support_for_preserve_create_times=`${custom_rsync_path_local_darwin} --help | grep -e "--crtimes" | awk '{print $1}' | grep -e "-N" | cut -c 1-2`
            installed_rsync_version_support_for_preserve_file_flags=`${custom_rsync_path_local_darwin} --help | grep -e "--fileflags" | awk '{print $1}' | grep -e "--fileflags"`
            installed_rsync_version_support_for_affect_immutable_files=`${custom_rsync_path_local_darwin} --help | grep -e "--force-change" | awk '{print $1}' | grep -e "--force-change"`
            
            # Check if the custom local version of rsync supports mac OSX meta data
            custom_rsync_path_local_supports_mac_osx_metadata="NO"
            if [ ${installed_rsync_version_number_major} -ge 3 ] && [ "${installed_rsync_version_support_for_preserve_create_times}" == "-N" ] && [ "${installed_rsync_version_support_for_preserve_file_flags}" == "--fileflags" ] && [ "${installed_rsync_version_support_for_affect_immutable_files}" == "--force-change" ] ; then
                custom_rsync_path_local_supports_mac_osx_metadata="YES"
            fi
            
        else
        
            # Check if there was a custom_rsync_path_local_darwin option set in the configuration
            if [ "${custom_rsync_path_local_darwin_overidden_by_configuration}" == "YES" ] ; then
                # Provide feed back that the specified custom_rsync_path_local_darwin option was not able to be found on the system
                echo "" | tee -ai $logFile
                echo "ERROR! : Specified custom version of rsync was not found on this system." | tee -ai $logFile
                echo "" | tee -ai $logFile
                echo "         Configuration specified the following : " | tee -ai $logFile
                echo "             custom_rsync_path_local_darwin=${custom_rsync_path_local_darwin}" | tee -ai $logFile
                echo "" | tee -ai $logFile
                echo "         Check that this specified custom version of rsync is installed at" | tee -ai $logFile
                echo "         the absolute path which is specified within the configuration." | tee -ai $logFile
                echo "" | tee -ai $logFile
				echo "         Backup canceled." | tee -ai $logFile
				echo "" | tee -ai $logFile
				send_mail_log
				exit -1
            fi
        
            echo "Checking Default Rsync Version..." | tee -ai $logFile
            installed_rsync_version="STANDARD"

            # Gathter Some Additional Information Regarding the Current Version of Rsync
            installed_rsync_version_number=`${default_ssh_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}'`
            installed_rsync_version_number_major=`${default_ssh_rsync_path_local_darwin} --version | head -n 1 | awk '{print $3}' | awk -F "." '{print $1}'`
            installed_rsync_version_support_for_preserve_create_times=`${default_ssh_rsync_path_local_darwin} --help | grep -e "--crtimes" | awk '{print $1}' | grep -e "-N" | cut -c 1-2`
            installed_rsync_version_support_for_preserve_file_flags=`${default_ssh_rsync_path_local_darwin} --help | grep -e "--fileflags" | awk '{print $1}' | grep -e "--fileflags"`
            installed_rsync_version_support_for_affect_immutable_files=`${default_ssh_rsync_path_local_darwin} --help | grep -e "--force-change" | awk '{print $1}' | grep -e "--force-change"`

        fi        
        
		
		# Parameters for selecting the standard version of rsync.
		
		# By default do we allow the default version of rsync.
		#accept_default_rsync_darwin="NO"
		accept_default_rsync_darwin="YES"
		
		if [ "$ssh_permit_standard_rsync_version" == "NO" ] && [ "$useSSH" == "YES" ]; then
			accept_default_rsync_darwin_remote_ssh="NO"
			accept_default_rsync_darwin="NO"
		fi
		
		# Determines that the minimum version of Darwin when using the local version of rysnc ( darwin version 8 is equivilent to tiger )
		darwin_standard_rsync_minimum_version_local=8
		
		# Determine whether the standard version of rsync is acceptable for local use
		# This depends upon two factors. The first factor is to do with the version of darwin on the local system.
		# The second factor involved is wheather this is a network backup (via SSH).
		if [ "${local_darwin_version}" != "ERROR" ] ; then
			if [ $local_darwin_version -ge $darwin_standard_rsync_minimum_version_local ] ; then
				if [ "$useSSH" == "YES" ] ; then
					if [ "${accept_default_rsync_darwin_remote_ssh}" == "YES" ] ; then
						# If the remote system and this system are running Mac OS X 10.4.x or greater we accept the
						# default version of rsync  bundeed with Mac OS X to be suffecient. Using the default version
						# of rsync which is bundeled with the Mac OS X will result in the resource forks sometimes
						# requring more storage space as they are not always hard linked correctly.
						accept_default_rsync_darwin="YES"	
					fi
				else 
				    if [ "${custom_rsync_path_local_supports_mac_osx_metadata}" == "YES" ] ; then
    		            # The custom version of Rsync supports all the Mac OS X support we require. Lets us it rather than the default Mac OS X version.
                        accept_default_rsync_darwin="NO"
    		        else
    					# Running a local backup on Mac OS X 10.4.x or greater and Rsync 3 is not available we accept the standard version of rsync
    					# This line means we are using the default Mac OS X bundled version of rsync. This dose require
    					# that we are running a good version and also not that resource forks, may take up more space.
    		            accept_default_rsync_darwin="YES"
    		        fi
                fi
			else
			    if [ "${accept_default_rsync_darwin_remote_ssh}" == "YES" ] ; then
						# If the remote system and this system are running Mac OS X 10.4.x or greater we accept the
						# default version of rsync bundled with Mac OS X to be sufficient. Using the default version
						# of rsync which is bundled with the Mac OS X will result in the resource forks sometimes
						# requiring more storage space as they are not always hard linked correctly.
						accept_default_rsync_darwin="YES"	
				else
                    if [ "$useSSH" == "NO" ] ; then
                        # Running a local backup on Mac OS X 10.3.9 or earlier. Therefore, we are not going to use 
                        # the default Mac OS X bundled version of rsync. 
                        accept_default_rsync_darwin="NO"
                    fi
                fi
			fi
		fi
		
		

        # Set hard link options appropriately 
        # Code is turning into spaghetti, this needs to be re-factored.
        # ( code will require tidy up - check for all possibilities on all plat forms )
        # needs to be made platform independent
        
        #
        # -e, --rsh=COMMAND           specify the remote shell
        # -a, --archive               archive mode, equivalent to -rlptgoD
        # -h, --help                  show this help screen
        # -s                          is unknowen
        # -f                          is unknowen
        # 
        
        # Set Hard Link Options to null
        hardlink_option=""
        
        function rsync_version_unkown {
            echo "ERROR! : Unknown Version of Rsync Installed" | tee -ai $logFile
            echo "         Check available rsync options, before proceeding " | tee -ai $logFile
            
            # Remove the backup lock file - probably not required - this will be handled by the trap
            rm -f "$backup_lock_file_absolute_path"
            exit -127
        }
        
        
        if [ "$installed_rsync_version" == "STANDARD" ] && [ "$accept_default_rsync_darwin" == "NO" ] ; then
                    echo "ERROR! : Only standard version of rsync installed" | tee -ai $logFile
					echo "         The standard rsync version will not preserve much meta data." | tee -ai $logFile
					echo "         Upgrade your OS or install the patched version of rsync." | tee -ai $logFile
					echo "         Download patched rsync version from the URL below :" | tee -ai $logFile
					echo "         http://www.lucidsystems.org/lbackup" | tee -ai $logFile
					echo "         Backup canceled." | tee -ai $logFile
					
					# Remove the backup lock file - probably not required - this will be handled by the trap
                    rm -f "$backup_lock_file_absolute_path"
                    exit -127
        fi
        
        if [ "$accept_default_rsync_darwin" == "NO" ] ; then
        
            # set the local rsync path to the default custom version of rsync
            rsync_path_local="$custom_rsync_path_local_darwin"

            # set the ssh remote rsync path to the default if it was not overridden in the configuration
            if [ "${ssh_rsync_path_remote_overidden_by_configuration}" == "NO" ] ; then
                ssh_rsync_path_remote="$custom_ssh_rsync_path_remote_darwin"
            fi

            # set the ssh remote rsync path to the default if it was not overridden in the configuration
            if [ "${ssh_rsync_path_local_overidden_by_configuration}" == "NO" ] ; then
               ssh_rsync_path_local="$custom_ssh_rsync_path_local_darwin"
            fi
            
        
            # check if we are running rsync version 3 or later		
    	    # This is only checking the local version. This should be updated to work with all versions.
    	    if [ ${installed_rsync_version_number_major} -ge 3 ]; then
    	        # Set options for rsync version 3 to preserve meta data on mac OS X
    	        
                echo "Using custom rsync : v3..." | tee -ai $logFile
                
                # This small x option will mean that we do not cross file system bounderies...think abou this....
           
                if [ "${custom_rsync_path_local_supports_mac_osx_metadata}" == "YES" ] ; then
                    #hardlink_option="-NHAXEx --protect-args --fileflags --force-change"
                    if [ "${disable_acl_preservation}" == "YES" ] ; then
                        # Remove the A (ACL) flag from the hard linking options
                        echo "Preservation of ACL's disabled" | tee -ai $logFile
                        hardlink_option="-NHXE --protect-args --fileflags --force-change"
                    else
                        hardlink_option="-NHAXE --protect-args --fileflags --force-change"
                    fi
                else
                    echo "WARNING : This copy of RSYNC may not support certain Mac OS X meta-data." | tee -ai $logFile
    	            #hardlink_option="-HAXEx --protect-args --fileflags --force-change"
					# This will also disable the "-N, --crtimes" rsync option - maybe a check can be added to see 
					# it is possible to leave the -N option?
    	            if [ "${disable_acl_preservation}" == "YES" ] ; then
                        # Remove the A (ACL) flag from the hard linking options
                        echo "Preservation of ACL's disabled" | tee -ai $logFile
    	                hardlink_option="-HXE --protect-args --fileflags --force-change"
	                else
	                    hardlink_option="-HAXE --protect-args --fileflags --force-change"
                    fi
    	        fi
    	    fi
    	

    		# If we are only accepting a patched version of rsync and the local rsync path has not been overidden,
    		# then lets set some options for meta data preseivation.
    		if [ "$accept_default_rsync_darwin" == "NO" ] && [ "${rsync_path_local_overidden_by_configuration}" == "NO" ]  && [ "${ssh_rsync_path_remote_overidden_by_configuration}" == "NO" ] && [ "${ssh_rsync_path_local_overidden_by_configuration}" == "NO" ] ; then
            	      
    	  		# Check for RsyncX or rsync (with fixed chown)
    	        if [ "$installed_rsync_version" == "rsync  version 2.6.0  protocol version 27" ] ; then
        
    	            # Check that the corrisponding os x package is installed
    	            rsync_search="RsyncX_v2.1.pkg"
    	            osx_package_check=`ls /Library/Receipts | grep -x "$rsync_search"`
            
    	            if [ "$osx_package_check" == "$rsync_search" ] ; then
                        echo "Using custom rsync : RsyncX..." | tee -ai $logFile
                        
    	                # We are deling with an older version of rsync (possibly RsyncX 2.1), this will require additional flags 
    	                hardlink_option="--eahfs"
    	            else
    	                # Unrcognised Version of Rsync
    	                rsync_version_unkown
    	            fi
            
    	        fi
        
            	# Check for chown Fixed Version of Rsync
    	        if [ "$installed_rsync_version" == "rsync  version 2.6.3  protocol version 28" ] ; then
    	            
    	            # Check that the corrisponding os x package is installed
    	            rsync_search="rsync.pkg"
    	            osx_package_check=`ls /Library/Receipts | grep -x "$rsync_search"`
        
    	            if [ "$osx_package_check" == "$rsync_search" ] ; then
                        echo "Using custom rsync : v2..." | tee -ai $logFile
    	              
    	                # We are deling with a patched version of rsync which is set to preserve some meta data 
    	                #hardlink_option="--hfs-mode=appledouble"
    	                hardlink_option=""
    	                echo "WARNING : This copy of RSYNC may not support certain Mac OS X meta-data." |  tee -ai $logFile
    	            else
    	                # Unrcognised Version of Rsync
    	                rsync_version_unkown
    	            fi
    	        fi
    	    fi

		else
			# Check if we are accepting the standard version of rsync
			# The standard version of rsync on the local machine is fine and or 
			# the standard version on the remote machine is fine for an SSH Backup
			if [ "$accept_default_rsync_darwin" == "YES" ] && [ ${installed_rsync_version_number_major} -le 2 ] ; then
				# The standard version of rsync is fine therefore lets set the preserver extended attributs option
				# for use with the standard version of rsync that shipped with this version of darwin. This can be abbriviated with -E
				# note that some extended-attributes with this option will take up extra space beacuase the standard version of rsync
				# is not able to hard link the resoruce forks for some files. 
				#hardlink_option="--extended-attributes"
                echo "WARNING : This copy of RSYNC may not support certain Mac OS X meta-data."
				hardlink_option="-E"
				#hardlink_option="-NHAXEx --protect-args --fileflags --force-change"
			fi	
			
		fi
		
    fi
fi


#This output is handy for development checking

#echo custom_rsync_path_local_supports_mac_osx_metadata : $custom_rsync_path_local_supports_mac_osx_metadata
#echo installed_rsync_version_support_for_preserve_file_flags : $installed_rsync_version_support_for_preserve_file_flags
#echo installed_rsync_version_support_for_affect_immutable_files : $installed_rsync_version_support_for_affect_immutable_files
#echo installed_rsync_version_support_for_preserve_create_times : $installed_rsync_version_support_for_preserve_create_times

#echo ssh_rsync_path_remote_overidden_by_configuration : $ssh_rsync_path_remote_overidden_by_configuration
#echo accept_default_rsync_darwin : $accept_default_rsync_darwin
#echo ssh_rsync_path_remote_overidden_by_configuration : $ssh_rsync_path_remote_overidden_by_configuration
#echo rsync_path_local_overidden_by_configuration : $rsync_path_local_overidden_by_configuration
#echo version : $installed_rsync_version_number_major
#echo hardlink_optons : $hardlink_option
#echo rsync path : $rsync_path_local
#exit 0


# Note that show to go is not supported by the new version of rsync.

if [ "$showProgress" == "YES" ] ; then
    if [ "$useSSH" == "YES" ] ; then
    	#SSH options

    	#options="--protocol=28 --rsync-path=${ssh_rsync_path_remote} --stats -az ${hardlink_option} --showtogo -e ssh --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"
        options="--rsync-path=${ssh_rsync_path_remote} ${change_options} ${checksum_options} ${numeric_id_options} ${preserve_hardlink_options} --stats -az ${hardlink_option} --showtogo --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES -e ssh"
        
    else
	   #nonSSH options

        options="--rsync-path=${rsync_path_local} ${change_options} ${checksum_options} ${numeric_id_options} ${preserve_hardlink_options} --stats -a ${hardlink_option} --showtogo --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"

    fi
else
    # Do not Show Progress
    if [ "$useSSH" == "YES" ] ; then
    	#SSH options

    	#options="--protocol=28 --rsync-path=${ssh_rsync_path_remote} --stats -az ${hardlink_option} -e ssh --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"
		
		if [ "${bandwidth_limit_enabled}" == "YES" ; then
			bandwidth_limit_options="--bandwidth_limit=${bandwidth_limit}"
			options="--rsync-path=${ssh_rsync_path_remote} ${change_options} ${checksum_options} ${numeric_id_options} ${bandwidth_limit_options} ${preserve_source_hardlink_options} --stats -az ${hardlink_option} --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES -e ssh"
		else
			options="--rsync-path=${ssh_rsync_path_remote} ${change_options} ${checksum_options} ${numeric_id_options} ${preserve_source_hardlink_options} --stats -az ${hardlink_option} --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES -e ssh"				
		fi

    else
	   #nonSSH options

        options="--rsync-path=${rsync_path_local} ${change_options} ${checksum_options} ${numeric_id_options} ${preserve_source_hardlink_options} --stats -a ${hardlink_option} --modify-window=20 --delete-excluded --exclude-from=$EXCLUDES"
		
    fi
fi





#################################
##   LBackup Specific Option   ##
#################################

if [ "${ignore_rsync_vanished_files}" == "YES" ] ; then
	echo "Ignoring rsync vanished file warnings..." | tee -ai $logFile
fi






########################
##   Perform Backup   ##
########################


echo "Synchronizing..." | tee -ai $logFile
sync_file_systems

if [ "${report_snapshot_time_human_readable}" == "YES" ] || [ "${report_snapshot_time_seconds}" == "YES" ] ; then
    epoch_before_rsync_run=`date "+%s"`
fi

if [ "$createLinks" == "NO" ] ; then
	# Do not Create Links
	if [ "$useSSH" == "YES" ] ; then
		#Source is accessed via SSH
		#time /usr/local/bin/rsync $options $sshSource:"$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
		time ${ssh_rsync_path_local} $options $sshSource:"$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile
	else
		#Source is locally available	
		#time /usr/local/bin/rsync $options "$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
	 	time ${rsync_path_local} $options "$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile
	fi	
else
	# Create Links
	echo "Creating Links" | tee -ai $logFile

	if [ "$useSSH" == "YES" ] ; then
		#Source is accessed via SSH
		#time /usr/local/bin/rsync $options --link-dest="$linkDest" $sshSource:"$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
		time ${ssh_rsync_path_local} $options --link-dest="$linkDest" $sshSource:"$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile
	else
		#Source is locally available	
		#time /usr/local/bin/rsync $options --link-dest="$linkDest" "$backupSource" "$backupDestCRotTemp" | tee -ai $logFile
		time ${rsync_path_local} $options --link-dest="$linkDest" "$backupSource" "$backupDestCRotTemp" 2>&1 | tee -ai $logFile
	fi
fi

if [ "${report_snapshot_time_human_readable}" == "YES" ] || [ "${report_snapshot_time_seconds}" == "YES" ] ; then
    epoch_after_rsync_run=`date "+%s"`
fi




# NOTE : The section above needs some work so that it is checking the return value from rsync.
#        some sort of system which allows certian rsync return values and disallowing other values is a possibility.

# Check the log to determin weather the backup completed
# Must be a better way than this....?

backupResult=`cat $logFile | tail -n 1 | grep "speedup" | awk '{ print $5 }'`
backupResultRsyncErrorCheck=`cat $logFile | tail -n 15 | grep "rsync error"`

# Check the data trasfer was not interupted - During This Sync
if [ "$backupResult" != "speedup" ] ; then
	if [ "${ignore_rsync_vanished_files}" == "YES" ] ; then
		# Not currenlty using rsync exit codes. Perhaps using the exit code from rsync would be a better approach?
		new_backupResult=`cat $logFile | tail -n 2 | head -n 1 | grep "speedup" | awk '{ print $5 }'`
		backupRsync_vanished_files_check_result=`cat $logFile | tail -n 1 | awk -F " at main.c" '{print $1}' | awk -F "rsync warning: " '{print $2}'`
		if [ "${new_backupResult}" != "speedup" ] || [ "${backupRsync_vanished_files_check_result}" != "some files vanished before they could be transferred (code 24)" ] ; then
			backup_status="FIALED"
		fi
	else
    	backup_status="FIALED"
	fi
fi


# If configured then report the time to for the snap shot process to compelte (eg rsync run time)
if [ "${report_snapshot_time_human_readable}" == "YES" ] || [ "${report_snapshot_time_seconds}" == "YES" ] ; then
    # This may also be enabled as debug in the future
    total_time_required_for_snapshot_in_seconds=`echo "${epoch_after_rsync_run} - ${epoch_before_rsync_run}" | bc -l`
    return_value_from_make_seconds_human_readable=""
    if [ "${total_time_required_for_snapshot_in_seconds}" == "" ] ; then
        echo "WARNING! : Unable to calculate the total time required for generation of snapshot." | tee -ai $logFile
    else
        # Calculate the human readable format in case it is required later (failed backup senario)
        make_seconds_human_readable "${total_time_required_for_snapshot_in_seconds}"
        # provided the backup has not failed report time taken
        if [ "$backup_status" != "FIALED" ] && [ "${report_snapshot_time_human_readable}" == "YES" ] ; then 
            echo "Time required for snapshot generation : ${return_value_from_make_seconds_human_readable}" | tee -ai $logFile
        fi
        if [ "$backup_status" != "FIALED" ] && [ "${report_snapshot_time_seconds}" == "YES" ] ; then 
            echo "Seconds required for snapshot generation : ${total_time_required_for_snapshot_in_seconds}" | tee -ai $logFile
        fi
    fi
fi






########################
##   Rotate Backups   ##
########################


# Check the data trasfer was not interupted - During This Sync
if [ "$backup_status" == "FIALED" ] ; then 
    
	echo "" | tee -ai $logFile    
	echo "WARNING! : Data Transfer Interrupted" | tee -ai $logFile
	
	# Check if we are meant to report the time spent on the incomplete transfer
	if [ "${report_snapshot_time_human_readable}" == "YES" ] ; then
	    echo "Time required for incomplete snapshot generation : ${return_value_from_make_seconds_human_readable}" | tee -ai $logFile
    fi
    if [ "${report_snapshot_time_seconds}" == "YES" ] ; then 
        echo "Seconds required for incomplete snapshot generation : ${total_time_required_for_snapshot_in_seconds}" | tee -ai $logFile
    fi
	
	if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # We are going to run post actions even though the backup has failed
        perform_post_action_scripts
    fi
	
	send_mail_log

	# Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
	exit -1
fi


# Check that RSYNC did not encouter any errors - Within 15 lines of logfile
if [ "$backupResultRsyncErrorCheck" != "" ] ; then
        
    backup_status="FIALED"
        
	echo "" | tee -ai $logFile  
	echo "WARNING! : RSYNC Encountered Errors" | tee -ai $logFile
	
	if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # We are going to run post actions even though the backup has failed
        perform_post_action_scripts
    fi
	
    send_mail_log
    
    # Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
    exit -1     
fi



# if there are rotations cronn the oldest one
if [ $numRotations -ge 1 ] ; then
    echo "" | tee -ai $logFile
	echo "Rotating Backups..." | tee -ai $logFile

	sync_file_systems
    confirm_backup_integraty
	
	# Setup Rotation Parameters
	locA=$[$numRotations-2]
	locB=$[$numRotations-1]

	# add the hard link option for the rotations


    # Remove the oldest rotation
    if [ -d "$backupDest/Section.$locB" ] ; then
        if [ "${report_removal_time_for_oldest_snap_shot_human_readable}" == "YES" ] || [ "${report_removal_time_for_oldest_snap_shot_seconds}" == "YES" ] ; then
		    epoch_before_oldest_remove=`date "+%s"`
	    fi
		rm -Rf "$backupDest/Section.$locB"
        if [ $? != 0 ] ; then
            current_user=`whoami`
            if [ "${current_user}" != "root" ] ; then
                chmod -R +w "$backupDest/Section.$locB/"*
                # Try the removal again
                rm -Rf "$backupDest/Section.$locB"
            fi
        fi
		# If configured then report the time to remove the oldest rotation
		if [ "${report_removal_time_for_oldest_snap_shot_human_readable}" == "YES" ] || [ "${report_removal_time_for_oldest_snap_shot_seconds}" == "YES" ] ; then
			# This may also be enabled as debug in the future
			epoch_after_oldest_remove=`date "+%s"`
			total_time_required_for_oldest_snap_shot_removal_in_seconds=`echo "${epoch_after_oldest_remove} - ${epoch_before_oldest_remove}" | bc -l`
			return_value_from_make_seconds_human_readable=""
			if [ "${total_time_required_for_oldest_snap_shot_removal_in_seconds}" == "" ] ; then
				echo "WARNING! : Unable to calculate the total time required for deletion of the oldest snapshot." | tee -ai $logFile
			else
			    if [ "${report_removal_time_for_oldest_snap_shot_human_readable}" == "YES" ] ; then
				    make_seconds_human_readable "${total_time_required_for_oldest_snap_shot_removal_in_seconds}"
				    echo "Time required for deletion of the oldest snapshot : ${return_value_from_make_seconds_human_readable}" | tee -ai $logFile
			    fi
			    if [ "${report_removal_time_for_oldest_snap_shot_seconds}" == "YES" ] ; then
			        echo "Seconds required for deletion of the oldest snapshot : ${total_time_required_for_oldest_snap_shot_removal_in_seconds}" | tee -ai $logFile
		        fi
			fi
		fi
    fi

	# Rotate the Current Sets
	while [ $locA -ge 0 ] ; do
		# Rotate this section
		if [ -d "$backupDest/Section.$locA" ] ; then
		      # not used for atomic backup - order is reversed
		      createLinks="YES"
              
              # Check the destination rotation is not going to be overwirtten (should never happen anyway)
              if ! [ -e "$backupDest/Section.$locB" ] ; then
		          mv -f "$backupDest/Section.$locA" "$backupDest/Section.$locB"
		          if [ $? != 0 ] ; then
                      # The last rotation had an error during the move. This must halt the backup.
		              echo "ERROR! : Performing Rotation" | tee -ai $logFile
		              echo "         Unable to perform rotation : \"$backupDest/Section.$locA\" to \"$backupDest/Section.$locB\"" | tee -ai $logFile
              	      backup_status="FIALED"
                      if [ "$post_actions_on_backup_error" == "YES" ] ; then
                          # We are going to run post actions even though the backup has failed
                          perform_post_action_scripts
                      fi
                      send_mail_log
                      # Remove the backup lock file - probably not required - this will be handled by the trap
                      rm -f "$backup_lock_file_absolute_path"
                      exit -1
                  fi
	          else
	              # The destination rotation is there and it should not be. It should have been moved out of the way. This must halt the backup.
	              echo "ERROR! : Performing Rotation" | tee -ai $logFile
		          echo "         Rotation found when not expected : \"$backupDest/Section.$locB\"" | tee -ai $logFile
        	      backup_status="FIALED"
                  if [ "$post_actions_on_backup_error" == "YES" ] ; then
                      # We are going to run post actions even though the backup has failed
                      perform_post_action_scripts
                  fi
                  send_mail_log
                  # Remove the backup lock file - probably not required - this will be handled by the trap
                  rm -f "$backup_lock_file_absolute_path"
                  exit -1
              fi
		fi
		locA=$[$locA-1]
		locB=$[$locB-1]
	done
fi


# Swap the finished backup into place
echo "Performing Atomic Swap..." | tee -ai $logFile

mv "$backupDestCRotTemp" "$backupDestCRot"
if [ $? != 0 ] ; then
	echo "ERROR! : Performing Atomic Swap" | tee -ai $logFile
	backup_status="FIALED"
	
    if [ "$post_actions_on_backup_error" == "YES" ] ; then
        # We are going to run post actions even though the backup has failed
        perform_post_action_scripts
    fi

    send_mail_log
    
    # Remove the backup lock file - probably not required - this will be handled by the trap
    rm -f "$backup_lock_file_absolute_path"
    exit -1
fi


# Perfrom post actions regardless of the atomic swap
perform_post_action_scripts


# Report if the Backup was Sccessfull.
if [ "${backup_status}" == "SUCCESS" ] ; then 
	epoch_successful_backup_finished=`date "+%s"`
    total_time_required_for_successful_backup_in_seconds=`echo "${epoch_successful_backup_finished} - ${epoch_successful_backup_start}" | bc -l`
    return_value_from_make_seconds_human_readable=""
    if [ "${total_time_required_for_successful_backup_in_seconds}" == "" ] ; then
        echo "WARNING! : Unable to calculate the total time required for sucesfull backup." | tee -ai $logFile
    else
		# Note : Time Elapsed is only sent to the log file.
		#        Human readable output could be loaded prior to this to the log and standard output if required.
		echo "Time elapsed in seconds : ${total_time_required_for_successful_backup_in_seconds}" >> $logFile
	fi
	echo "Backup Completed Successfully" | tee -ai $logFile
fi


 

## Close Log File
echo "" >> $logFile
echo "" >> $logFile
echo "" >> $logFile



# If requested by the configuration, run lmail even if the backup was successful.
# This is an experimental setting which may be removed in a future release.
if [ "$email_and_archive_log_on_successful_backup" == "YES" ] && [ "$mailconfigpartner" != "" ] ; then
        send_mail_log
fi



# Report backup has run via Growl.

if [ "$sendGrowlNotification" == "YES" ] ; then

        # Set Growl Out Location 
        growl_out_location="/usr/sbin/growlout"

        echo "Sending Growl Notification..."
        
        if [ "$useSSH" == "YES" ] ; then
            ssh $sshSource "$growl_out_location"
        fi
        if [ "$useSSH" == "NO" ] ; then
			# Check growlout is installed 
			if [ -f "$growl_out_location" ] ; then
            	"/usr/sbin/growlout"
			else
				echo "   WARNING! : Growl out was not installed at : $growl_out_location"
			fi
        fi
        
fi


# Remove the backup lock file - probably not required - this will be handled by the trap
rm -f "$backup_lock_file_absolute_path"


# Sleep machine if configured in backup configuration
if [ "$SLEEP" == "YES" ] ; then
    if [ $useSSH == "YES" ] ; then
        echo "Requesting Sleep..."
        ssh $sshSource "/usr/sbin/sleepy"
    fi
    if [ $useSSH == "NO" ] ; then
        /usr/sbin/sleepy
    fi
fi


exit 0


